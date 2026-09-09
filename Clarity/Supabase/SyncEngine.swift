import Foundation
import Supabase
import SwiftData
import WidgetKit

/// Row shape of the public `tasks` table (see supabase/migrations/*).
/// Snake-case property names double as the JSON keys — no custom CodingKeys.
struct ServerTask: Codable {
    var id: String
    var user_id: String
    var title: String
    var due_at: String?
    var is_completed: Bool
    var created_at: String?
    var updated_at: String
}

enum ISODate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func string(from date: Date) -> String { withFraction.string(from: date) }

    static func date(from string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }
}

/// Local-first sync: SwiftData stays the fast offline mirror (widget reads
/// it), Supabase is the cloud truth for future cross-platform clients.
/// Push debounced on every mutation, pull on launch / focus / every 60s.
/// Conflicts: last-write-wins on `updatedAt`.
@MainActor
@Observable
final class SyncEngine {
    enum Status: Equatable {
        case idle, syncing, offline, error(String)

        var label: String {
            switch self {
            case .idle: return "Synced"
            case .syncing: return "Syncing…"
            case .offline: return "Local only"
            case .error: return "Sync error"
            }
        }
    }

    static let shared = SyncEngine()

    private(set) var status: Status = .idle

    private var container: ModelContainer?
    private var debounce: Task<Void, Never>?
    private var syncing = false
    private var periodicStarted = false

    private init() {}

    private var client: SupabaseClient? { AuthService.shared.client }
    private var userId: UUID? { AuthService.shared.userId }

    func configure(container: ModelContainer) {
        self.container = container
    }

    /// Call after any local mutation. Coalesces rapid edits into one push.
    func pushSoon() {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func startPeriodic() {
        guard !periodicStarted else { return }
        periodicStarted = true
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self?.syncNow()
            }
        }
    }

    func syncNow() async {
        guard !syncing else { return }
        guard let client, let uid = userId, let container else {
            if status != .syncing { status = .offline }
            return
        }
        syncing = true
        status = .syncing
        defer { syncing = false }
        do {
            let context = container.mainContext
            try await push(client: client, uid: uid, in: context)
            try await pull(client: client, uid: uid, in: context)
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
            status = .idle
        } catch {
            print("SyncEngine: \(error)")
            status = .error(error.localizedDescription)
        }
    }

    /// Fire-and-forget server delete for locally deleted tasks.
    func deleteRemotely(ids: [String]) {
        guard let client, let uid = userId, !ids.isEmpty else { return }
        Task {
            for id in ids {
                _ = try? await client.from("tasks")
                    .delete()
                    .eq("id", value: id)
                    .eq("user_id", value: uid.uuidString)
                    .execute()
            }
        }
    }

    // MARK: - Push / Pull

    private func push(client: SupabaseClient, uid: UUID, in context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.needsSync }
        ))
        guard !pending.isEmpty else { return }
        for task in pending {
            let row = ServerTask(
                id: task.id,
                user_id: uid.uuidString,
                title: task.title,
                due_at: task.dueDate.map(ISODate.string(from:)),
                is_completed: task.isCompleted,
                created_at: ISODate.string(from: task.createdAt),
                updated_at: ISODate.string(from: task.updatedAt)
            )
            try await client.from("tasks").upsert(row).execute()
            task.needsSync = false
        }
        try context.save()
    }

    private func pull(client: SupabaseClient, uid: UUID, in context: ModelContext) async throws {
        let rows: [ServerTask] = try await client.from("tasks")
            .select()
            .eq("user_id", value: uid.uuidString)
            .execute().value
        for row in rows {
            let id = row.id
            let found = try context.fetch(FetchDescriptor<TodoTask>(
                predicate: #Predicate { $0.id == id }
            )).first
            if let local = found {
                // Last-write-wins: server wins only if strictly newer.
                if let serverDate = ISODate.date(from: row.updated_at),
                   serverDate > local.updatedAt {
                    apply(row, to: local)
                }
            } else {
                let task = TodoTask(
                    title: row.title,
                    dueDate: row.due_at.flatMap(ISODate.date(from:)),
                    isCompleted: row.is_completed
                )
                task.id = row.id
                if let created = row.created_at.flatMap(ISODate.date(from:)) {
                    task.createdAt = created
                }
                if let updated = ISODate.date(from: row.updated_at) {
                    task.updatedAt = updated
                }
                task.needsSync = false
                context.insert(task)
                if let due = task.dueDate {
                    _ = due // notifications for pulled tasks are (re)scheduled below
                    NotificationManager.schedule(for: task)
                }
            }
        }
        try context.save()
    }

    private func apply(_ row: ServerTask, to task: TodoTask) {
        let wasCompleted = task.isCompleted
        task.title = row.title
        task.dueDate = row.due_at.flatMap(ISODate.date(from:))
        task.isCompleted = row.is_completed
        if let updated = ISODate.date(from: row.updated_at) {
            task.updatedAt = updated
        }
        task.needsSync = false
        if wasCompleted != task.isCompleted {
            if task.isCompleted {
                NotificationManager.cancel(for: task)
            } else {
                NotificationManager.schedule(for: task)
            }
        }
    }
}

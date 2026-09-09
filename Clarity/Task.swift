import Foundation
import SwiftData

@Model
final class TodoTask {
    var id: String // Permanent ID — also the primary key in Supabase (client-generated UUID)
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    /// Last local mutation time. Drives last-write-wins sync + server `updated_at`.
    var updatedAt: Date
    /// True when local changes haven't been pushed to Supabase yet.
    var needsSync: Bool

    init(title: String, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.id = UUID().uuidString // Automatically generates a unique tracking number
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    /// Call after any local mutation so sync picks it up.
    func touch() {
        updatedAt = Date()
        needsSync = true
    }

    /// Display sort: earliest due date first, undated after dated,
    /// ties broken by creation time.
    static func sortForDisplay(_ lhs: TodoTask, _ rhs: TodoTask) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?): return l < r
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.createdAt < rhs.createdAt
        }
    }

    var isDueTodayOrOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return Calendar.current.compare(due, to: Date(), toGranularity: .day) != .orderedDescending
    }
}

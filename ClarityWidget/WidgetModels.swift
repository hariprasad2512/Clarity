import Foundation
import SwiftData
import SwiftUI

// Widget-local copies of the app's model layer.
//
// The widget extension is a separate binary and cannot see the Clarity app
// target's classes, so the types below mirror (property-for-property)
// Clarity/Task.swift and Clarity/Shared/*.
// KEEP THEM IN SYNC: same class name (TodoTask), same properties, same
// App Group ID — that is what lets both binaries open the same .store file.

@Model
final class TodoTask {
    var id: String
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    // Mirrors the app target's sync fields property-for-property so both
    // binaries open the same store. The widget never writes them.
    var updatedAt: Date
    var needsSync: Bool

    init(title: String, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.id = UUID().uuidString
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    static func sortForDisplay(_ lhs: TodoTask, _ rhs: TodoTask) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?): return l < r
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.createdAt < rhs.createdAt
        }
    }
}

enum SharedStore {
    static let appGroupID = "group.com.harry.Clarity"
    static let storeFileName = "clarity.store"

    static var sharedStoreURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        return container.appendingPathComponent(storeFileName)
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([TodoTask.self])
        let config: ModelConfiguration
        if let url = sharedStoreURL {
            config = ModelConfiguration(schema: schema, url: url, allowsSave: true)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("SharedStore(widget): persistent failed (\(error)), using in-memory")
            let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [mem])
        }
    }
}

enum DateParser {
    static func displayString(for date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if date < Date() { return "Overdue · \(date.formatted(date: .abbreviated, time: .shortened))" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

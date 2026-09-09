import Foundation
import SwiftData
import WidgetKit

/// Shared mutation helpers used by Main window, Quick-Add bar, and Widget intent.
/// Every mutation refreshes widget timelines so the Desktop widget never goes stale.
enum TaskService {
    /// Extract natural date, insert, save, schedule, refresh widget.
    @MainActor
    @discardableResult
    static func add(
        title rawInput: String,
        manualDate: Date? = nil,
        in context: ModelContext
    ) -> TodoTask? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Manual date keeps the typed title verbatim; auto mode strips the
        // detected date words Todoist-style ("Call mom tomorrow" -> "Call mom").
        let title: String
        let dueDate: Date?
        if let manualDate {
            title = trimmed
            dueDate = manualDate
        } else {
            let parsed = DateParser.extractDateAndCleaned(from: trimmed)
            title = parsed.title
            dueDate = parsed.date
        }

        let task = TodoTask(title: title, dueDate: dueDate)
        context.insert(task)
        do {
            try context.save()
        } catch {
            print("TaskService.add save failed: \(error)")
        }
        NotificationManager.schedule(for: task)
        WidgetCenter.shared.reloadAllTimelines()
        SyncEngine.shared.pushSoon()
        return task
    }

    @MainActor
    static func toggle(_ task: TodoTask, in context: ModelContext) {
        task.isCompleted.toggle()
        task.touch()
        if task.isCompleted {
            NotificationManager.cancel(for: task)
        } else {
            NotificationManager.schedule(for: task)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        SyncEngine.shared.pushSoon()
    }

    @MainActor
    static func delete(_ tasks: [TodoTask], in context: ModelContext) {
        let ids = tasks.map(\.id)
        for task in tasks {
            NotificationManager.cancel(for: task)
            context.delete(task)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        SyncEngine.shared.deleteRemotely(ids: ids)
        SyncEngine.shared.pushSoon()
    }
}

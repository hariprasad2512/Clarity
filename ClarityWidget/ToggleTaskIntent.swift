import AppIntents
import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// Interactive-widget action: tap a task's circle in the Desktop widget
/// to complete / reopen it without opening Clarity.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle task"
    static var description = IntentDescription("Mark a Clarity task complete or incomplete.")

    @Parameter(title: "Task ID")
    var taskID: String

    init() { taskID = "" }

    init(taskID: String) {
        self.taskID = taskID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = SharedStore.makeContainer()
        let context = ModelContext(container)
        let id = taskID
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try? context.fetch(descriptor).first {
            task.isCompleted.toggle()
            if task.isCompleted {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: [task.id])
            } else if let due = task.dueDate, due > Date() {
                // Re-schedule a basic reminder when reopening (title-only,
                // matching NotificationManager: icon identifies the app)
                let content = UNMutableNotificationContent()
                content.title = task.title
                content.sound = .default
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: due
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: task.id, content: content, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(request)
            }
            try? context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

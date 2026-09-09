import Foundation
import UserNotifications

/// All UserNotifications logic in one place (main app + quick-add + widget intent).
enum NotificationManager {
    static let categoryID = "CLARITY_TASK_DUE"
    static let markDoneActionID = "CLARITY_MARK_DONE"
    static let snoozeActionID = "CLARITY_SNOOZE"

    /// "Remind me later" delay, editable in Settings (⌘,). Default 60 min.
    static var snoozeMinutes: Int {
        let stored = UserDefaults.standard.integer(forKey: "snoozeMinutes")
        return stored > 0 ? stored : 60
    }

    static var snoozeLabel: String {
        let m = snoozeMinutes
        if m < 60 { return "Remind me in \(m) min" }
        let h = m / 60
        let rest = m % 60
        if rest == 0 { return h == 1 ? "Remind me in 1 hour" : "Remind me in \(h) hours" }
        return "Remind me in \(h)h \(rest)m"
    }

    static func requestPermission() {
        registerCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permission granted.")
            } else if let error {
                print("Error requesting permission: \(error.localizedDescription)")
            }
        }
    }

    /// (Re)registers the actionable category. Called at launch, on permission
    /// grant, and whenever the snooze setting changes (action title is dynamic).
    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: markDoneActionID,
            title: "Mark Done",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: snoozeLabel,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [done, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func schedule(for task: TodoTask) {
        guard let dueDate = task.dueDate, !task.isCompleted else { return }
        guard dueDate > Date() else { return } // don't schedule past dates

        // Title-only: the app icon already identifies Clarity, so the task
        // itself gets the prominent slot. No subtitle/body.
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.sound = .default
        content.categoryIdentifier = categoryID

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: task.id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Error scheduling notification: \(error.localizedDescription)") }
        }
    }

    static func cancel(for task: TodoTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id])
    }
}

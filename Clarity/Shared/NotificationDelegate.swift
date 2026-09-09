import AppKit
import SwiftData
import UserNotifications
import WidgetKit

/// Handles notification taps: default tap opens the app, Mark Done completes
/// the task, snooze pushes it out by the Settings-configured delay.
///
/// Installed in `ClarityApp.init` (not onAppear) so actions also work when
/// macOS launches us in the background for a tap while quit.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private var container: ModelContainer?

    private override init() { super.init() }

    func configure(container: ModelContainer) {
        self.container = container
    }

    // Show banners even when Clarity is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            self.handle(response)
        }
    }

    private func handle(_ response: UNNotificationResponse) {
        let taskID = response.notification.request.identifier
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            showMainWindow()
        case NotificationManager.markDoneActionID:
            complete(taskID: taskID)
        case NotificationManager.snoozeActionID:
            snooze(taskID: taskID)
        default:
            break
        }
    }

    private func withTask(_ id: String, _ work: (TodoTask, ModelContext) -> Void) {
        guard let container else { return }
        let context = container.mainContext
        let target = id
        guard let task = (try? context.fetch(FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.id == target }
        )))?.first else { return }
        work(task, context)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        SyncEngine.shared.pushSoon()
    }

    private func complete(taskID: String) {
        withTask(taskID) { task, _ in
            guard !task.isCompleted else { return }
            task.isCompleted = true
            task.touch()
            NotificationManager.cancel(for: task)
        }
    }

    private func snooze(taskID: String) {
        let minutes = NotificationManager.snoozeMinutes
        withTask(taskID) { task, _ in
            guard !task.isCompleted else { return }
            task.dueDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            task.touch()
            NotificationManager.schedule(for: task)
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where type(of: window) == NSWindow.self {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

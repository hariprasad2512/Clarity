import AppKit
import SwiftData
import SwiftUI
import UserNotifications

@main
struct ClarityApp: App {
    /// Shared container: App Group store when entitled, local otherwise.
    /// Created once so main window + quick-add panel see the same data.
    private let container: ModelContainer = SharedStore.makeContainer()

    init() {
        // Notification actions must work even when tapped while quit, so the
        // delegate + categories are installed here, before any window appears.
        NotificationDelegate.shared.configure(container: container)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationManager.registerCategories()

        // Wire global hotkey -> Spotlight panel (registered on appear too,
        // this covers early key presses).
        HotKeyManager.shared.onToggle = {
            Task { @MainActor in
                QuickAddPanelManager.shared.toggle()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AuthService.shared)
                .environment(SyncEngine.shared)
                .onAppear {
                    QuickAddPanelManager.shared.configure(container: container)
                    HotKeyManager.shared.register()
                    // Cloud: restore session, pull truth, start background sync.
                    AuthService.shared.start()
                    SyncEngine.shared.configure(container: container)
                    Task {
                        await SyncEngine.shared.syncNow()
                    }
                    SyncEngine.shared.startPeriodic()
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.didBecomeActiveNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task { await SyncEngine.shared.syncNow() }
                    }
                }
                // Deep-link target for widget taps (clarity://today).
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(container)
        .handlesExternalEvents(matching: ["today"])

        Settings {
            SettingsView()
        }

        // Menu bar: fast capture without hunting the Dock
        MenuBarExtra("Clarity", systemImage: "checkmark.circle") {
            Button("Quick add task…  ⌘⇧T") {
                QuickAddPanelManager.shared.show()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()

            Button("Show main window") {
                NSApp.activate(ignoringOtherApps: true)
                // NSWindow exactly (not NSPanel) so we don't resurrect the quick-add bar
                for window in NSApp.windows where type(of: window) == NSWindow.self {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("Quit Clarity") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

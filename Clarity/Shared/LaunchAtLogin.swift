import Foundation
import ServiceManagement

/// Opt-in launch at login so ⌘⇧T capture survives reboots and quits.
///
/// Uses `SMAppService.mainApp` (macOS 13+, sandbox-safe, no extra
/// entitlements). Note: with the main window closed the app already keeps
/// running (menu bar + hotkey alive) — this only covers full quit/reboot.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLogin: \(error.localizedDescription)")
        }
    }
}

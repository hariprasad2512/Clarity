import SwiftUI
import UserNotifications

/// Native Settings window (⌘,). Home of the "Remind me later" delay.
struct SettingsView: View {
    @AppStorage("snoozeMinutes") private var snoozeMinutes: Int = 60

    private let options = [15, 30, 60, 120, 180]

    var body: some View {
        Form {
            Section("Notifications") {
                Picker("Remind me later waits", selection: $snoozeMinutes) {
                    ForEach(options, id: \.self) { m in
                        Text(label(for: m)).tag(m)
                    }
                }
                .onChange(of: snoozeMinutes) {
                    // Refresh the action button title on pending UI.
                    NotificationManager.registerCategories()
                }
                Text("Tapping “Remind me later” on a due alert moves the task out by this long.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("Capture") {
                Text("Press ⌘⇧T anywhere to capture without opening Clarity. Enable “Launch at login” in the sidebar to keep it alive across reboots.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }

    private func label(for minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        if minutes == 60 { return "1 hour" }
        return "\(minutes / 60) hours"
    }
}

import SwiftData
import SwiftUI

enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case inbox = "Inbox"
    case done = "Done"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .inbox: return "tray"
        case .done: return "checkmark.circle"
        }
    }
}

/// Slim Todoist-style sidebar: views on top, account + sync at the bottom.
struct SidebarView: View {
    @Environment(AuthService.self) private var auth
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var modelContext

    @Binding var filter: TaskFilter
    var todayCount: Int
    var inboxCount: Int

    @State private var launchAtLogin = false
    @State private var hoveredFilter: TaskFilter?
    @State private var quickAddHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Quick capture entry point
            Button {
                QuickAddPanelManager.shared.show()
            } label: {
                Label("Quick Add  ⌘⇧T", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(quickAddHovered ? Color.green.opacity(0.85) : Color.green)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .onHover { quickAddHovered = $0 }
            .padding()

            // Explicit tap rows (not NavigationLink): the detail column is a
            // static view, so navigation-driven selection never propagated.
            List {
                Section("Tasks") {
                    ForEach(TaskFilter.allCases) { f in
                        HStack {
                            Label(f.rawValue, systemImage: f.systemImage)
                            Spacer()
                            if let b = badge(for: f) { b.foregroundColor(.secondary) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { filter = f }
                        .onHover { hoveredFilter = $0 ? f : nil }
                        .listRowBackground(rowBackground(for: f))
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            Divider()

            // Account + sync footer
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(initial)
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(accountTitle)
                            .font(.callout)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncDot)
                                .frame(width: 7, height: 7)
                            Text(sync.status.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                if auth.isSignedIn {
                    Button("Sign out") {
                        auth.signOut(clearing: modelContext)
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                } else if auth.isConfigured {
                    Button("Sign in") {
                        auth.offlineMode = false
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                } else {
                    Text("Cloud sync not set up — see README")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Keeps ⌘⇧T capture alive across quits and reboots.
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .font(.callout)
                    .tint(.green)
                    .onChange(of: launchAtLogin) { _, on in
                        LaunchAtLogin.setEnabled(on)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                    .onAppear {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func rowBackground(for f: TaskFilter) -> Color {
        if f == filter { return Color.green.opacity(0.25) }
        if hoveredFilter == f { return Color.green.opacity(0.12) }
        return Color.clear
    }

    private func badge(for f: TaskFilter) -> Text? {
        switch f {
        case .today: return todayCount > 0 ? Text("\(todayCount)") : nil
        case .inbox: return inboxCount > 0 ? Text("\(inboxCount)") : nil
        case .done: return nil
        }
    }

    private var initial: String {
        guard let email = auth.userEmail, let first = email.first else { return "○" }
        return String(first).uppercased()
    }

    private var accountTitle: String {
        if let email = auth.userEmail { return email }
        return auth.isConfigured ? "Offline" : "Local only"
    }

    private var syncDot: Color {
        switch sync.status {
        case .idle: return .green
        case .syncing: return .orange
        case .offline: return .gray
        case .error: return .red
        }
    }
}

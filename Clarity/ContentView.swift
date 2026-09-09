import SwiftData
import SwiftUI

/// Shell: login gate when cloud is configured + signed out,
/// otherwise the sidebar + list workspace.
struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @Query private var tasks: [TodoTask]

    @State private var filter: TaskFilter = .today
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    private var todayCount: Int {
        tasks.filter(\.isDueTodayOrOverdue).count
    }

    private var inboxCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        if auth.isConfigured && !auth.isSignedIn && !auth.offlineMode {
            AuthView()
        } else {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(filter: $filter, todayCount: todayCount, inboxCount: inboxCount)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
            } detail: {
                TaskListView(filter: filter, tasks: tasks)
            }
            .frame(minWidth: 760, idealWidth: 1000, minHeight: 560, idealHeight: 700)
            .tint(.green)
            .onAppear {
                NotificationManager.requestPermission()
            }
        }
    }
}

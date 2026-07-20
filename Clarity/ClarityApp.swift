import SwiftUI
import SwiftData

@main
struct ClarityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This is the magic line that fixes your bug!
        // It tells the app to use YOUR Task rules.
        .modelContainer(for: TodoTask.self)
    }
}

import Foundation
import SwiftData

/// Single source of truth for the App Group + shared SwiftData store.
///
/// Widget + main app must read the SAME .store file. If the App Group
/// entitlement isn't enabled yet (fresh clone, no paid team), this
/// gracefully falls back to the default local store so the app still runs.
/// Once you enable `group.com.harry.Clarity` in Signing & Capabilities
/// for BOTH targets, data is shared automatically.
enum SharedStore {
    static let appGroupID = "group.com.harry.Clarity"
    static let storeFileName = "clarity.store"

    static var sharedStoreURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        return container.appendingPathComponent(storeFileName)
    }

    static var isSharingEnabled: Bool { sharedStoreURL != nil }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([TodoTask.self])
        let config: ModelConfiguration
        if let url = sharedStoreURL {
            config = ModelConfiguration(
                schema: schema,
                url: url,
                allowsSave: true
            )
        } else {
            // Fallback: default local store (works before App Group is set up)
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Last resort: in-memory so the app never crashes on launch
            print("SharedStore: failed to create persistent container (\(error)), using in-memory")
            let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [mem])
        }
    }
}

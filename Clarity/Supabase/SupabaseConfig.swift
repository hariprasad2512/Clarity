import Foundation

/// Reads Supabase credentials from `Clarity/SupabaseConfig.plist`.
///
/// That file is gitignored (see `SupabaseConfig.template.plist` at the repo
/// root). When it's missing or empty the app runs in local-only mode:
/// SwiftData + notifications + widget all keep working, cloud sync is off.
/// This keeps fresh clones and CI building with zero secrets.
enum SupabaseConfig {
    static let callbackScheme = "com.harry.Clarity"
    static var callbackURL: URL {
        URL(string: "\(callbackScheme)://oauth-callback")!
    }

    private static var plist: [String: String]? {
        guard let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = obj as? [String: String]
        else { return nil }
        return dict
    }

    static var projectURL: URL? {
        guard let raw = plist?["url"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, !raw.contains("YOUR-"),
              let url = URL(string: raw)
        else { return nil }
        return url
    }

    static var anonKey: String? {
        guard let raw = plist?["anonKey"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, !raw.contains("YOUR-")
        else { return nil }
        return raw
    }

    static var isConfigured: Bool {
        projectURL != nil && anonKey != nil
    }
}

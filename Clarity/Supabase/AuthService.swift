import Foundation
import Supabase
import SwiftData

/// Google-only sign-in via Supabase Auth. Owns the SupabaseClient.
/// Unconfigured (no SupabaseConfig.plist) -> `client == nil`, everything
/// else in the app must treat that as local-only mode, never crash.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private(set) var isConfigured = false
    private(set) var isSigningIn = false
    var errorMessage: String?

    /// Set true from AuthView ("Continue offline") to skip the login gate.
    var offlineMode = false

    private(set) var client: SupabaseClient?
    private var listener: Task<Void, Never>?

    private init() {}

    var isSignedIn: Bool { session != nil }
    var userEmail: String? { session?.user.email }
    var userId: UUID? { session?.user.id }

    /// Call once at launch (after the ModelContainer exists).
    func start() {
        guard SupabaseConfig.isConfigured,
              let url = SupabaseConfig.projectURL,
              let key = SupabaseConfig.anonKey
        else {
            isConfigured = false
            return
        }
        isConfigured = true
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        self.client = client
        // The stream replays `.initialSession` on subscribe, so this also
        // restores a persisted Keychain session with no extra code.
        listener?.cancel()
        listener = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                self.session = session
                if event == .signedIn {
                    self.isSigningIn = false
                    self.offlineMode = false
                    self.errorMessage = nil
                    // Fresh login: pull the cloud truth, then push anything local.
                    await SyncEngine.shared.syncNow()
                } else if event == .signedOut {
                    self.session = nil
                }
            }
        }
    }

    func signInWithGoogle() {
        guard let client else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await client.auth.signInWithOAuth(
                    provider: .google,
                    redirectTo: SupabaseConfig.callbackURL
                )
                // Session arrives via authStateChanges (.signedIn).
            } catch {
                isSigningIn = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Signs out of Supabase AND wipes local tasks (privacy on shared Macs).
    func signOut(clearing context: ModelContext) {
        Task {
            try? await client?.auth.signOut()
            session = nil
            offlineMode = false
            do {
                try context.delete(model: TodoTask.self)
                try context.save()
            } catch {
                print("AuthService: local wipe failed: \(error)")
            }
        }
    }
}

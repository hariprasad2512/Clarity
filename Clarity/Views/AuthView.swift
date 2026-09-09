import SwiftUI

/// Login gate. Google-only (per scope). When Supabase isn't configured yet
/// (fresh clone, no SupabaseConfig.plist) this explains setup instead of
/// showing a dead button — the app stays usable offline.
struct AuthView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                Text("Clarity")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("A minimal todo app.\nYour tasks, everywhere.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if auth.isConfigured {
                    Button {
                        auth.signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            if auth.isSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "globe")
                            }
                            Text(auth.isSigningIn ? "Opening Google…" : "Sign in with Google")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isSigningIn)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .frame(maxWidth: 320)
                            .multilineTextAlignment(.center)
                    }

                    Button("Continue offline") {
                        auth.offlineMode = true
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.secondary)
                } else {
                    // Unconfigured: onboarding for the repo owner, offline entry for everyone.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cloud sync isn't set up in this build.")
                            .font(.headline)
                        Text("To enable Google sign-in:\n1. Create a free Supabase project\n2. Copy SupabaseConfig.template.plist → Clarity/SupabaseConfig.plist\n3. Fill in your project URL + anon key\n4. Add Google OAuth in Supabase Auth settings")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(12)
                    .frame(maxWidth: 380)

                    Button("Continue offline") {
                        auth.offlineMode = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
            Spacer()
            Text("Local tasks always work — sync just makes them follow you.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .frame(minWidth: 520, minHeight: 560)
    }
}

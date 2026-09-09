# Contributing to Clarity

Thanks for stopping by. Clarity is a minimal, open-source (MIT) todo app for macOS.

## What you need

- macOS with **Xcode 26.6+** (Swift 6, macOS 26 SDK)
- An Apple ID added in Xcode → Settings → Accounts (free Personal Team is fine)
- Optional: a free [Supabase](https://supabase.com) project for cloud sync testing

## First run (5 minutes)

1. Clone and open `Clarity.xcodeproj`.
2. Select the **Clarity** target → Signing & Capabilities:
   - Set **Team** to yours.
   - Confirm the App Group `group.com.harry.Clarity` is checked
     (replace the prefix with your own Team-based group if Xcode complains,
     and mirror it in `SharedStore.appGroupID` + both entitlements files).
3. Do the same Team step for the **ClarityWidget** target.
4. Press Run. The app works fully offline out of the box.

> Without a Team / App Group the app still builds and runs (local store
> fallback) — only widget data-sharing needs the group.

## Enabling Google sign-in + sync

1. Create a Supabase project, run **every** file in `supabase/migrations/`
   in its SQL Editor, in order.
2. Supabase Dashboard → Authentication → Providers → enable **Google**:
   create the OAuth client in Google Cloud Console, add the redirect URL
   `com.harry.Clarity://oauth-callback` to Supabase's Redirect URLs
   (Authentication → URL Configuration).
3. Copy `SupabaseConfig.template.plist` → `Clarity/SupabaseConfig.plist`
   and fill in your project URL + anon key. This file is gitignored —
   **never commit keys**.
4. Re-run. Sign in with Google from the app.

## Cutting a release (maintainers)

1. Build Release, sign with the dev identity (both targets, entitlements),
   verify with `codesign --verify --deep --strict`.
2. Zip with `ditto -c -k --sequesterRsrc --keepParent` (never plain `zip`).
3. `gh release create vX.Y.Z <zip>` with notes — the `bump-cask.yml`
   workflow updates the Homebrew tap automatically (needs the `TAP_TOKEN`
   secret; see [AGENTS.md](AGENTS.md) §6).

## Ground rules

- **Minimal by design.** If a feature needs an explanation, it probably
  doesn't belong. Prefer removing UI over adding settings.
- **Local-first.** The widget and offline mode must keep working with zero
  network. Cloud sync is a mirror, never a dependency.
- **Sync contract.** Task identity = client-generated UUID (`TodoTask.id`
  ↔ `tasks.id`). Conflicts resolve last-write-wins on `updated_at`.
  The widget's `WidgetModels.swift` mirrors the `@Model` fields
  property-for-property — change one, change both, or the shared store
  won't open.
- **No secrets in PRs.** CI builds with signing off and no Supabase keys.
- Run both schemes (`Clarity`, `ClarityWidget`) in Debug before opening a PR.
- Update [CHANGELOG.md](CHANGELOG.md) with user-facing changes.

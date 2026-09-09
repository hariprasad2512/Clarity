# AGENTS.md — Clarity cross-platform contract

> Read this before writing any Clarity client (macOS, iOS, Android, web).
> The backend is the source of truth; platforms are thin mirrors of it.

## 1. What Clarity is

Minimal Todoist-style todo app. Philosophy: **local-first, minimal by
design, no feature bloat**. If a feature needs an explanation, it doesn't
belong. Reference implementation: this repo's macOS app (`Clarity/`).

## 2. Repo map (macOS reference)

| Path | Role |
|---|---|
| `Clarity/Task.swift` | `@Model TodoTask`: `id, title, dueDate?, isCompleted, createdAt, updatedAt, needsSync` |
| `Clarity/Shared/` | `SharedStore` (App Group SwiftData), `TaskService` (mutations), `DateParser` (NLP dates + title strip), `NotificationManager/Delegate`, `LaunchAtLogin` |
| `Clarity/QuickAdd/` | Spotlight bar: key-capable `NSPanel`, Carbon `⌘⇧T` hotkey |
| `Clarity/Views/` | `ContentView` shell, `SidebarView`, `TaskListView`, `AuthView`, `SettingsView` |
| `Clarity/Supabase/` | `AuthService` (Google OAuth), `SyncEngine` (push/pull, LWW), `SupabaseConfig` |
| `ClarityWidget/` | Widget + `ToggleTaskIntent`. **Mirror rule:** `WidgetModels.swift` MUST match `Task.swift` property-for-property or the shared store won't open |
| `supabase/migrations/` | Ordered SQL. Run all, in order, on any new project |
| `SupabaseConfig.template.plist` | Copy → `Clarity/SupabaseConfig.plist` (gitignored, never commit keys) |

## 3. Shared data contract (ALL clients obey this)

- **Table `public.tasks`**: `id uuid PK` *(client-generated v4 UUID string — offline creates need no round-trip)*, `user_id uuid → auth.users (delete cascade)`, `title text`, `due_at timestamptz null`, `is_completed bool`, `created_at / updated_at timestamptz`. **No priority column** (removed in `20260909000001_drop_priority.sql`).
- **Dates on the wire**: ISO-8601 strings (`due_at`, `updated_at`); accept fractional seconds.
- **RLS**: `auth.uid() = user_id` on all operations. Never query without the user scope.
- **Conflicts**: last-write-wins on `updated_at` (server wins only if strictly newer).
- **Deletes**: hard delete locally + `DELETE` remotely by `(id, user_id)`. No tombstones in v1.
- **Sorting**: earliest `due_at` first, undated last, ties by `created_at`. Today = due today or overdue, incomplete only.
- **Auth**: Supabase Google OAuth (PKCE handled by each platform's SDK). Redirect scheme per platform, e.g. macOS `com.harry.Clarity://oauth-callback`. Session in OS keychain/keystore; sign-out wipes local tasks on shared devices.

## 4. Sync rules (mirror the reference `SyncEngine`)

1. Local store is the fast offline mirror; Supabase is cloud truth.
2. Every local mutation stamps `updatedAt = now`, `needsSync = true`, debounces a push.
3. Sync = **push pending upserts → pull all user rows → apply LWW → save → refresh widgets**.
4. Pull on launch, on foreground, and every ~60s. Multi-device realtime is a future upgrade, not v1 scope.

## 5. Client sketches (future)

- **iOS (SwiftUI)**: reuse `supabase-swift`; SwiftData mirror + same `SyncEngine` shape; WidgetKit extension reuses the mirror-model rule; Google OAuth redirect `com.harry.Clarity.ios://oauth-callback`.
- **Android (Kotlin)**: `supabase-kt` (Auth + PostgREST), Room entity mirroring §3 columns, WorkManager periodic pull, Material 3 UI, Google One-Tap → Supabase `signInWithIdToken`.
- **Web (Next.js)**: `supabase-js`, the same `supabase/migrations/` applied to the same project, `supabase.auth.signInWithOAuth({ provider: 'google' })`.
- All three share: §3 schema/RLS/LWW, §4 sync order, Google-only auth, title-only notification (or platform-equivalent) copy.

## 6. Conventions for agents

- **No secrets in repo**: only `*.template.*` files. Scan diffs for keys/tokens before every commit.
- **Minimal UI**: sidebar/list-equivalent hierarchy, one capture entry, green accent on Apple platforms.
- **Conventional commits** (`feat:`, `fix:`, `chore:`); PRs build clean before review.
- **Verify matrix (macOS)**: `xcodebuild build -scheme Clarity{,Widget} -configuration Debug|Release` with `CODE_SIGNING_ALLOWED=NO` for CI; signed Xcode run for device/widget data-sharing tests.
- **Notification interop**: category `CLARITY_TASK_DUE`, actions Mark Done / snooze-by-`snoozeMinutes` (default 60). Reuse these IDs/meanings on every platform.

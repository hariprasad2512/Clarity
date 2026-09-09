# Clarity

A minimal, open-source (MIT) todo app for macOS. Capture fast, track simply,
sync everywhere.

## ✨ Features

- **Spotlight-style quick add** — `Cmd+Shift+T` from any app opens a floating
  bar (above fullscreen apps, cursor ready, `Enter` saves, `Esc` dismisses).
  Natural dates (`"Pay rent tomorrow at 5pm"`, even `"6.20 pm"`);
  detected date words are stripped Todoist-style. Optional **Launch at
  login** keeps capture alive across reboots.
- **Clean workspace** — sidebar (Today / Inbox / Done with counts) + focused
  list, search, one-line capture with calendar/clock scheduling, adaptive
  hover states, overdue highlighting.
- **Calendar scheduling** — month grid plus Today / Tomorrow / Weekend
  presets; manual picks override auto-parse.
- **Smart actionable alerts** — the task title is the notification, with
  **Mark Done** and **Remind me later** buttons (delay configurable in
  Settings, default 1 hour).
- **Desktop widget** — Today's tasks on your Mac desktop; tap a circle to
  complete without opening the app.
- **Google sign-in + cloud sync** — Supabase Auth + Postgres. Local-first:
  everything works offline; sync is a mirror, never a dependency.
- **Privacy-first default** — without cloud setup, data stays in local
  SwiftData. No account, no tracking.

## 🛠️ Built with

SwiftUI · SwiftData · WidgetKit + AppIntents · UserNotifications ·
Supabase (Auth + Postgres) · NSDataDetector for natural-language dates

## 💾 Install (recommended)

```sh
brew tap hariprasad2512/clarity
brew trust hariprasad2512/clarity   # one time, third-party tap
brew install --cask clarity
```

Keep it updated with `brew upgrade --cask clarity` (new releases bump the
tap automatically — see [CHANGELOG.md](CHANGELOG.md)).

- Requires macOS 26+. First launch needs a one-time Finder right-click →
  Open (free Apple ID signature, not notarized) — afterwards it just works.
- Or download the latest `Clarity-macOS-vX.Y.Z.zip` from
  [Releases](../../releases), move Clarity into Applications, then
  `xattr -cr /Applications/Clarity.app`.
- The widget shares data via the App Group `group.com.harry.Clarity`; a
  Team-signed build enables it automatically.

## 🚀 Build it

1. Open `Clarity.xcodeproj` in Xcode 26.6+.
2. Set your **Team** on the Clarity + ClarityWidget targets, check the
   App Group `group.com.harry.Clarity` on both.
3. Run. Works offline immediately.

### Cloud sync (optional)

1. Create a free Supabase project; run every file in `supabase/migrations/`
   in its SQL Editor, in order.
2. Enable the **Google** provider in Supabase Auth; add redirect URL
   `com.harry.Clarity://oauth-callback`.
3. `cp SupabaseConfig.template.plist Clarity/SupabaseConfig.plist`,
   fill in your URL + anon key (gitignored — never commit).
4. Re-run and sign in.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor guide and
[AGENTS.md](AGENTS.md) for the agent/cross-platform contract.

## 🗺️ Cross-platform future

The `public.tasks` table is the shared contract: client-generated UUID ids,
per-user RLS, last-write-wins on `updated_at`. Any future iOS / Android / web
client syncs against the same schema — start at [AGENTS.md](AGENTS.md).

## 📄 License

MIT — see [LICENSE](LICENSE).

# Changelog

User-facing history. Bearers of bad news first: breaking/schema notes inline.

## v2.0.1 — 2026-09-09

- Patch: refreshed capture placeholder.
- First release carried by the Homebrew tap (auto-bumped by CI).

## v2.0.0 — 2026-09-09

- Sidebar workspace (Today / Inbox / Done) + slim capture bar.
- Spotlight quick-add (`Cmd+Shift+T`), launch at login, menu bar.
- Google sign-in + Supabase sync (local-first, last-write-wins).
- Actionable notifications: Mark Done, Remind me later (configurable delay).
- Desktop widget with tap-to-complete, shared App Group store.
- Natural-language dates with Todoist-style title cleanup.
- **Breaking: priorities removed** from app, widget, and database
  (`20260909000001_drop_priority.sql`).
- Open source: MIT license, README, CONTRIBUTING, AGENTS.md.

## v1.0.0 — 2026-07-20

- Initial beta: local SwiftData tasks, natural dates, notifications.

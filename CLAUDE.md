# Locked In — dev notes

macOS menu bar app (SwiftUI, SPM, no Xcode project). Design doc: docs/DESIGN.md.

## Build & run

```bash
./scripts/bundle.sh          # swift build + assemble dist/LockedIn.app
open dist/LockedIn.app
```

`swift run` works for quick iteration but launch-at-login and Secrets.plist
need the real bundle.

## Machine quirk (fixed 2026-07-26)

This machine's Command Line Tools were a corrupted multi-year version mix
(stale private.swiftinterface files, SDK/compiler swiftlang mismatch) that
broke every `swift build`. Fixed by full CLT reinstall from
developer.apple.com (the `xcode-select --install` dialog failed with "not
available from the Software Update server"). `scripts/bundle.sh` keeps a
harmless auto-detect for the stale-interface variant of this problem.

## Architecture (small on purpose)

- `IdleTracker` — global idle seconds via CGEventSource, no TCC permissions
- `LocalStore` — daily totals in UserDefaults, key = local `yyyy-MM-dd`
- `SyncClient` — raw PostgREST over URLSession (no Supabase SDK); 5 calls total
- `AppState` — 5s tick (idle < 60s → +5s today), 60s heartbeat, 30s board poll
- `PanelView` — the entire UI, one popover
- Presence states (grinding / idle Nm / last seen) are computed client-side
  from `heartbeat_at` + `last_active_at`; rules in docs/DESIGN.md

Backend: `supabase/schema.sql`. Board reads go through the `get_group_board`
RPC (one round trip). Credentials resolve Secrets.plist (bundled) →
UserDefaults (settings UI); absent both, the app runs solo.

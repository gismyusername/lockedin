# Locked In 🔥

A tiny macOS menu bar app that tracks how much you actually work — hands on
keyboard, not apps open — and puts you on a live leaderboard with your friends.

- **`● 4:12 | 2 grinding`** in your menu bar, all day, automatically
- **Live presence**: see which friends are locked in *right now*
- **Daily leaderboard** with streaks
- **Zero permission prompts**: no Accessibility, no Screen Recording, nothing
- **Private by design**: only your display name, locked-in seconds, and online
  status ever leave your Mac. No app names, no window titles, no screenshots.

Requires macOS 13 Ventura or later.

## How the score works

You're "locked in" whenever your last keyboard or mouse input was under 60
seconds ago. That's it. No app categorization, no judging whether Chrome is
work. If your hands are moving, you're grinding.

## Install (friends)

1. Download `LockedIn.zip` from the latest [Release](../../releases), unzip,
   drag `LockedIn.app` to Applications.
2. The app is not notarized (we're cheap). On first launch macOS will block it:
   open **System Settings → Privacy & Security**, scroll down, click
   **Open Anyway**. You only do this once.
   - Terminal alternative: `xattr -d com.apple.quarantine /Applications/LockedIn.app`
3. Launch it and pick a display name. If the build was made with a default
   group configured, you're on the leaderboard immediately — no code to type.
   Otherwise, **Create a group** or **Join** with a friend's invite code.
4. In settings (gear icon), enable **Launch at login**. Done — never touch it again.

## Build from source

```bash
git clone <this repo> && cd lockedin
./scripts/bundle.sh            # debug build → dist/LockedIn.app
./scripts/bundle.sh release    # universal release build
```

## Backend setup (one person does this once)

1. Create a free project at [supabase.com](https://supabase.com).
2. Paste `supabase/schema.sql` into the SQL editor and run it.
3. Put the project URL and anon key into the app's settings (gear icon), or
   into repo secrets `SUPABASE_URL` / `SUPABASE_ANON_KEY` so releases ship
   pre-wired.
4. Optional: set repo secret `DEFAULT_GROUP_CODE` to your group's invite code.
   Every fresh install then joins that group by itself, so friends only type a
   name. Leaving the group in settings is sticky — the app won't drag you back
   in.

## Releasing

Tag a version and push — GitHub Actions builds, bundles, and attaches the zip:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Design

The full design doc (metric choice, presence rules, trade-offs) lives in
[docs/DESIGN.md](docs/DESIGN.md); the original wireframe is
[docs/wireframe.png](docs/wireframe.png).

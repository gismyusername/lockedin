#!/bin/bash
# Builds dist/LockedIn.dmg: the app beside an Applications alias, so people
# install by dragging instead of running the app from Downloads (where macOS
# translocates it to a random read-only path and login-item registration
# silently fails).
#
# Usage: scripts/make-dmg.sh [path/to/LockedIn.app]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-dist/LockedIn.app}"
[ -d "$APP" ] || { echo "no app at $APP — run scripts/bundle.sh first" >&2; exit 1; }

VOL="Locked In"
STAGE=$(mktemp -d)
# The scratch image must live outside the staged folder, or hdiutil tries to
# package the image into itself and dies with "No space left on device".
WORK=$(mktemp -d)
DMG_RW="$WORK/rw.dmg"
mkdir -p dist

cp -R "$APP" "$STAGE/LockedIn.app"
ln -s /Applications "$STAGE/Applications"
# Volume icon, so the mounted disk shows the bolt too. Needs the "has custom
# icon" flag, which SetFile sets when Xcode is installed; skipped otherwise.
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
fi
mkdir -p "$STAGE/.background"
cp Resources/dmg-background.png "$STAGE/.background/background.png"
# Prebaked window layout (icon positions, background, view mode). CI has no
# Finder to produce one, so the committed copy is what makes the released DMG
# look the same as a locally built one. Regenerate with scripts/restyle-dmg.sh.
[ -f Resources/dmg-DS_Store ] && cp Resources/dmg-DS_Store "$STAGE/.DS_Store"

# Writable image first: Finder can only style a mounted read-write volume.
# Size explicitly with headroom — hdiutil's auto-size is too tight for HFS+
# metadata on a small payload and fails with "No space left on device".
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 48 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ \
    -size "${SIZE_MB}m" -format UDRW -ov "$DMG_RW" >/dev/null

MOUNT=$(hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen | \
        grep -o '/Volumes/.*' | head -1)
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rm -rf "$STAGE" "$WORK"' EXIT

# Re-apply styling through Finder when a GUI session exists. Skipped on CI,
# where the prebaked .DS_Store above already carries the layout.
if [ "${SKIP_FINDER:-0}" = "1" ]; then
  echo "note: SKIP_FINDER set, relying on prebaked .DS_Store"
else
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "note: Finder styling unavailable, shipping unstyled DMG"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 150, 800, 550}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set background picture of opts to file ".background:background.png"
    set position of item "LockedIn.app" of container window to {150, 170}
    set position of item "Applications" of container window to {450, 170}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT
fi

if [ -f "$MOUNT/.VolumeIcon.icns" ] && command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT" || true
fi

sync
hdiutil detach "$MOUNT" -quiet
trap 'rm -rf "$STAGE" "$WORK"' EXIT

rm -f dist/LockedIn.dmg
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o dist/LockedIn.dmg >/dev/null
echo "Built: dist/LockedIn.dmg ($(du -h dist/LockedIn.dmg | cut -f1))"

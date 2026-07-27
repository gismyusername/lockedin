#!/bin/bash
# Renders HistoryView to a PNG with seeded data, so calendar layout can be
# reviewed without clicking through the menu bar popover. Writes to /tmp and
# opens it.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -O Sources/LockedIn/LocalStore.swift Sources/LockedIn/MonthGrid.swift \
       Sources/LockedIn/Models.swift Sources/LockedIn/HistoryView.swift \
       Tests/Preview/main.swift -o "$OUT/preview"
(cd "$OUT" && ./preview)
rm -f "$HOME/Library/Preferences/preview.plist"
mv "$OUT/history-preview.png" /tmp/history-preview.png
rm -rf "$OUT"
echo "/tmp/history-preview.png"
open /tmp/history-preview.png

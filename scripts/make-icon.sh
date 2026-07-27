#!/bin/bash
# Regenerates Resources/AppIcon.icns from Tests/IconAssets/main.swift.
# Only needed when the icon design changes; the .icns is committed.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -O Tests/IconAssets/main.swift -o "$OUT/mkicon"
"$OUT/mkicon" "$OUT/AppIcon.iconset"
iconutil -c icns "$OUT/AppIcon.iconset" -o Resources/AppIcon.icns
rm -rf "$OUT"
echo "Rebuilt Resources/AppIcon.icns"

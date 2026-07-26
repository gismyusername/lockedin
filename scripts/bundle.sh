#!/bin/bash
# Assemble LockedIn.app from the swift build output.
# Usage: scripts/bundle.sh [debug|release]  (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

# --- CLT workaround -------------------------------------------------------
# Some Command Line Tools installs carry stale (2024) private.swiftinterface
# files next to a newer PackageDescription dylib, which breaks every
# `swift build` with "Invalid manifest" link errors. If detected, build a
# cleaned copy of the manifest libs and point SwiftPM at it.
CLT_PM="/Library/Developer/CommandLineTools/usr/lib/swift/pm"
STALE="$CLT_PM/ManifestAPI/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface"
if [ -f "$STALE" ] && [ "$STALE" -ot "$CLT_PM/ManifestAPI/libPackageDescription.dylib" ]; then
  FIXED_PM="$HOME/.cache/lockedin/pm"
  if [ ! -d "$FIXED_PM/ManifestAPI" ]; then
    echo "Stale CLT manifest interfaces detected — using cleaned copy at $FIXED_PM"
    mkdir -p "$FIXED_PM"
    cp -R "$CLT_PM/ManifestAPI" "$FIXED_PM/ManifestAPI"
    cp -R "$CLT_PM/PluginAPI" "$FIXED_PM/PluginAPI"
    find "$FIXED_PM" -name "*.private.swiftinterface" -delete
  fi
  export SWIFTPM_CUSTOM_LIBS_DIR="$FIXED_PM"
fi
# --------------------------------------------------------------------------

CONFIG="${1:-debug}"
if [ "$CONFIG" = "release" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=".build/apple/Products/Release/LockedIn"
else
  swift build
  BIN=".build/debug/LockedIn"
fi

APP="dist/LockedIn.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LockedIn"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Bake in backend credentials for local builds when Secrets.plist exists.
[ -f Secrets.plist ] && cp Secrets.plist "$APP/Contents/Resources/Secrets.plist"
# Ad-hoc sign so the app runs locally without a developer certificate.
codesign --force --deep -s - "$APP" 2>/dev/null || true
echo "Bundled: $APP"

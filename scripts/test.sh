#!/bin/bash
# Compiles the real LocalStore.swift together with the test harness and runs it.
# Not XCTest: the app is a single executable target, and a library split would
# be more ceremony than these few invariants deserve.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -O Sources/LockedIn/LocalStore.swift Sources/LockedIn/MonthGrid.swift Sources/LockedIn/BoardRange.swift Sources/LockedIn/InstallToApplications.swift Tests/LocalStoreTests/main.swift -o "$OUT/storetest"
"$OUT/storetest"
rm -rf "$OUT" "$HOME/Library/Preferences/storetest.plist"

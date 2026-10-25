#!/usr/bin/env bash
# Runs every package test suite: host `swift test` for CapoCore, CapoData and CapoSupabase,
# then CapoUI-Package on the first available iPhone simulator.
# Usage: ios/scripts/test-packages.sh [derived-data-dir]   (default: ios/build/dd-tests)
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${1:-$IOS_DIR/build/dd-tests}"

echo "==> design tokens (web vs iOS)"
node "$IOS_DIR/scripts/check-design-tokens.mjs"

for pkg in CapoCore CapoData CapoSupabase; do
  echo "==> swift test ($pkg)"
  (cd "$IOS_DIR/Packages/$pkg" && swift test)
done

SIM_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for d in entries:
        if d["name"].startswith("iPhone"):
            print(d["udid"]); sys.exit(0)
sys.exit(1)
')"

echo "==> xcodebuild test CapoUI-Package (simulator $SIM_ID)"
(cd "$IOS_DIR/Packages/CapoUI" && xcodebuild \
  -scheme CapoUI-Package \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$DERIVED" \
  test)

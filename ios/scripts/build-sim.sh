#!/usr/bin/env bash
# Builds the Capo app for the iOS Simulator without signing.
# Usage: ios/scripts/build-sim.sh [derived-data-dir]   (default: ios/build/dd-sim)
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${1:-$IOS_DIR/build/dd-sim}"

xcodebuild \
  -project "$IOS_DIR/Capo/Capo.xcodeproj" \
  -scheme Capo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

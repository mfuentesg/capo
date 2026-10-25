#!/usr/bin/env bash
# Builds, installs and launches Capo on a connected device (integrator only).
# Usage: ios/scripts/install-device.sh [iphone|ipad|<device-id>]   (default: iphone)
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-iphone}" in
  iphone) DEVICE_ID="00008110-00141CE43AC2401E" ;;
  ipad) DEVICE_ID="00008112-00111110215A201E" ;;
  *) DEVICE_ID="$1" ;;
esac
DERIVED="$IOS_DIR/build/dd-device"

xcodebuild \
  -project "$IOS_DIR/Capo/Capo.xcodeproj" \
  -scheme Capo \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app --device "$DEVICE_ID" "$DERIVED/Build/Products/Debug-iphoneos/Capo.app"
xcrun devicectl device process launch --device "$DEVICE_ID" com.mfuentesg.capo

#!/usr/bin/env bash
# Builds (Release), signs, and installs the app on an iPhone connected by USB using
# a free Apple ID (Personal Team). With that account the app expires after 7 days:
# renew it by running this same script. See docs/SETUP.md ("Installing on an iPhone").
#
# Usage:
#   IOS_TEAM_ID=XXXXXXXXXX scripts/install-ios.sh [iPhone-UDID]
#
# IOS_TEAM_ID: team ID (Xcode → Settings → Accounts → your team, or
#   `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier | grep teamID`).
# UDID: optional if a single physical iPhone is connected (`flutter devices` lists it).
#
# Requirements: Xcode with your Apple ID in Accounts, iPhone with Developer Mode,
# unlocked and set to "Trust this computer"; mobile/ios/Runner/GoogleService-Info.plist.
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.example.budgettool}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
PLIST="$MOBILE/ios/Runner/GoogleService-Info.plist"

TEAM_ID="${IOS_TEAM_ID:-}"
if [ -z "$TEAM_ID" ]; then
  echo "Missing IOS_TEAM_ID (Apple team ID)." >&2
  echo "  Example: IOS_TEAM_ID=XXXXXXXXXX $0" >&2
  echo "  Find it in Xcode → Settings → Accounts, or with:" >&2
  echo "    defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier | grep teamID" >&2
  exit 1
fi

if [ ! -f "$PLIST" ]; then
  echo "Missing $PLIST (download it from Firebase Console; it is gitignored). See docs/SETUP.md." >&2
  exit 1
fi

cd "$MOBILE"

DEVICE_ID="${1:-${IOS_DEVICE_ID:-}}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
devs = [d["id"] for d in json.load(sys.stdin)
        if d.get("targetPlatform") == "ios" and not d.get("emulator")]
print(devs[0] if len(devs) == 1 else "")
')"
  if [ -z "$DEVICE_ID" ]; then
    echo "Could not pick a single iPhone. Connect/unlock it or pass the UDID as an argument:" >&2
    flutter devices >&2
    exit 1
  fi
fi
echo "→ iPhone: $DEVICE_ID | team: $TEAM_ID"

echo "→ Preparing the project (flutter build ios --no-codesign)…"
flutter build ios --release --no-codesign >/dev/null

echo "→ Building and signing…"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination "id=$DEVICE_ID" -derivedDataPath build/ios/xcode-dd \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" build | tail -n 3

APP="build/ios/xcode-dd/Build/Products/Release-iphoneos/Runner.app"
echo "→ Installing…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" | tail -n 3

echo "→ Opening the app…"
if ! xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "Could not open it automatically. If this is the first time: iPhone → Settings → General →" >&2
  echo "VPN & Device Management → trust your Apple ID and open the app manually." >&2
fi
echo "Done. It expires in 7 days (free Apple ID): run this script again to renew it."

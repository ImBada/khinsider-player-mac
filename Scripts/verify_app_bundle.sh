#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-dist/KHPlayer.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/KHPlayer"
ICON_FILE="$APP_PATH/Contents/Resources/AppIcon.icns"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist: $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing executable: $EXECUTABLE" >&2
  exit 1
fi

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing app icon: $ICON_FILE" >&2
  exit 1
fi

plutil -lint "$INFO_PLIST" >/dev/null

EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
PACKAGE_TYPE=$(/usr/libexec/PlistBuddy -c "Print :CFBundlePackageType" "$INFO_PLIST")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")
ICON_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$INFO_PLIST")

if [[ "$EXECUTABLE_NAME" != "KHPlayer" ]]; then
  echo "Unexpected CFBundleExecutable: $EXECUTABLE_NAME" >&2
  exit 1
fi

if [[ "$PACKAGE_TYPE" != "APPL" ]]; then
  echo "Unexpected CFBundlePackageType: $PACKAGE_TYPE" >&2
  exit 1
fi

if [[ "$BUNDLE_ID" != "com.bada.khinsider-player-mac" ]]; then
  echo "Unexpected CFBundleIdentifier: $BUNDLE_ID" >&2
  exit 1
fi

if [[ "$ICON_NAME" != "AppIcon" ]]; then
  echo "Unexpected CFBundleIconFile: $ICON_NAME" >&2
  exit 1
fi

echo "Verified app bundle: $APP_PATH"

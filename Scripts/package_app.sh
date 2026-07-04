#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="KHPlayer"
DISPLAY_NAME="KHInsider Player"
BUNDLE_ID="com.bada.khinsider-player-mac"
VERSION="${VERSION:-0.1.1}"
BUILD_NUMBER="${BUILD_NUMBER:-2}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://imbada.github.io/khinsider-player-mac/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ "${REQUIRE_SPARKLE_KEYS:-0}" == "1" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is required when REQUIRE_SPARKLE_KEYS=1." >&2
  exit 1
fi

swift build -c "$CONFIGURATION"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BIN_DIR/KHInsiderPlayerMac_KHPlayer.bundle"
ICON_SOURCE="Sources/KHPlayer/Resources/AppIcon.icns"
SPARKLE_FRAMEWORK="$(find .build -path "*/Sparkle.framework" -type d | head -n 1)"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Missing built executable: $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ -z "$SPARKLE_FRAMEWORK" || ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Missing Sparkle.framework in SwiftPM build artifacts." >&2
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Frameworks"

cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
ditto "$SPARKLE_FRAMEWORK" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

if command -v install_name_tool >/dev/null 2>&1; then
  if ! otool -l "$APP_PATH/Contents/MacOS/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_PATH/Contents/MacOS/$APP_NAME"
  fi
fi

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
fi

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.music</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUAutomaticallyUpdate</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_PATH/Contents/Frameworks/Sparkle.framework" >/dev/null
  codesign --force --sign - "$APP_PATH" >/dev/null
fi

bash Scripts/verify_app_bundle.sh "$APP_PATH"
echo "$APP_PATH"

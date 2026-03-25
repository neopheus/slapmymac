#!/bin/bash
set -euo pipefail

# Create a distributable DMG for SlapMyMac
# Prerequisites: build.sh --release must be run first
# Optional: code signing and notarization

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/SlapMyMac.app"
DMG_NAME="SlapMyMac"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Error: App bundle not found. Run ./Scripts/build.sh --release first."
    exit 1
fi

# Optional: Code sign
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    echo "Signing app with: $DEVELOPER_ID"
    codesign --force --deep --options runtime \
        --sign "$DEVELOPER_ID" \
        "$APP_BUNDLE"
fi

# Create staging directory
echo "Creating DMG..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create symlink to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
rm -f "$DMG_PATH"
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Cleanup staging
rm -rf "$STAGING_DIR"

# Optional: Notarize
if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_PASSWORD:-}" ]]; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "DMG created at: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

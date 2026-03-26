#!/bin/bash
set -euo pipefail

# Build SlapMyMac and create an .app bundle
# Usage: ./Scripts/build.sh [--release] [--sandbox]
#
# Options:
#   --release    Build in release mode
#   --sandbox    Sign with App Sandbox entitlements (required for App Store)
#
# Environment variables (optional):
#   DEVELOPER_ID   Code signing identity (default: ad-hoc "-")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="SlapMyMac"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS="$PROJECT_DIR/Sources/SlapMyMac/Resources/SlapMyMac.entitlements"

# Parse arguments
CONFIG="debug"
SWIFT_FLAGS=""
SANDBOX=false

for arg in "$@"; do
    case "$arg" in
        --release) CONFIG="release"; SWIFT_FLAGS="-c release" ;;
        --sandbox) SANDBOX=true ;;
    esac
done

echo "Building SlapMyMac ($CONFIG$([ "$SANDBOX" = true ] && echo ", sandboxed"))..."

cd "$PROJECT_DIR"

# Build with SPM
swift build $SWIFT_FLAGS

# Find the built executable
EXECUTABLE="$BUILD_DIR/$CONFIG/$APP_NAME"
if [[ ! -f "$EXECUTABLE" ]]; then
    echo "Error: Executable not found at $EXECUTABLE"
    exit 1
fi

# Create .app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/SlapMyMac/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy sound resources from the SPM bundle
RESOURCE_BUNDLE="$BUILD_DIR/$CONFIG/SlapMyMac_SlapMyMac.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE/Sounds" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Also copy sounds directly for fallback
SOUNDS_DIR="$PROJECT_DIR/Sources/SlapMyMac/Resources/Sounds"
if [[ -d "$SOUNDS_DIR" ]]; then
    cp -R "$SOUNDS_DIR" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy Sparkle.framework into the app bundle (required for dynamic linking)
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_FW="$BUILD_DIR/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
    cp -R "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"
    # Fix rpath so the executable can find the framework
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    echo "Sparkle.framework bundled."
fi

# Sign with entitlements if --sandbox is set
if [[ "$SANDBOX" == true ]]; then
    SIGNING_ID="${DEVELOPER_ID:--}"
    echo "Signing with sandbox entitlements (identity: $SIGNING_ID)..."
    codesign --force --sign "$SIGNING_ID" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "Signed with App Sandbox entitlements."
fi

echo ""
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "To install: cp -R $APP_BUNDLE /Applications/"

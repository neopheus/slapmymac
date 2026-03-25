#!/bin/bash
set -euo pipefail

# Build SlapMyMac and create an .app bundle
# Usage: ./Scripts/build.sh [--release]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="SlapMyMac"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Determine build configuration
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
    SWIFT_FLAGS="-c release"
else
    CONFIG="debug"
    SWIFT_FLAGS=""
fi

echo "Building SlapMyMac ($CONFIG)..."

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

echo ""
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "To install: cp -R $APP_BUNDLE /Applications/"

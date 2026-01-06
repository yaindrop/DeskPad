#!/bin/bash
set -e

APP_NAME="DeskPad"
BUNDLE_ID="com.stengo.DeskPad"
OUTPUT_DIR=".build/release"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
EXECUTABLE_NAME="DeskPad"
ICON_SOURCE="DeskPad/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$OUTPUT_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Process Icon
if [ -f "$ICON_SOURCE" ]; then
    echo "Processing App Icon..."
    ICONSET_DIR="DeskPad.iconset"
    mkdir -p "$ICONSET_DIR"

    # Resize images
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

    # Create icns
    iconutil -c icns "$ICONSET_DIR"
    cp DeskPad.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    
    # Cleanup
    rm -rf "$ICONSET_DIR"
    rm DeskPad.icns
    echo "Icon processed."
else
    echo "Warning: $ICON_SOURCE not found. App will use default icon."
fi

# Copy Info.plist
echo "Copying Info.plist..."
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Signing
echo "Signing..."
if [ -f "DeskPad/DeskPad.entitlements" ]; then
    echo "Using entitlements..."
    codesign --force --deep --entitlements "DeskPad/DeskPad.entitlements" --sign - "$APP_BUNDLE"
else
    echo "No entitlements found, standard signing..."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "Done! App is at $APP_BUNDLE"
echo "You can open it with: open $APP_BUNDLE"

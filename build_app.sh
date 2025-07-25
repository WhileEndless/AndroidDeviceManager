#!/bin/bash

# Android Device Manager Build Script
# Usage: ./build_app.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_NAME="Android Device Manager"
BUNDLE_ID="com.androiddevicemanager.macos"
VERSION="1.0.0"

echo -e "${GREEN}=== Building $APP_NAME v$VERSION ===${NC}"

# Step 1: Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf ".build"
rm -rf "$APP_NAME.app"
rm -f "AndroidDeviceManager.dmg"

# Step 2: Build release version
echo -e "${YELLOW}Building release version...${NC}"
swift build -c release --product AndroidDeviceManager

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Step 3: Create app bundle structure
echo -e "${YELLOW}Creating app bundle...${NC}"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Step 4: Copy executable
cp ".build/release/AndroidDeviceManager" "$APP_NAME.app/Contents/MacOS/"

# Step 5: Update Info.plist with current values
cat > "$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AndroidDeviceManager</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <string>YES</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Step 6: Sign the app (ad-hoc signing)
echo -e "${YELLOW}Signing app...${NC}"
codesign --force --deep -s - "$APP_NAME.app"

if [ $? -ne 0 ]; then
    echo -e "${RED}Code signing failed!${NC}"
    exit 1
fi

# Step 7: Verify the app
echo -e "${YELLOW}Verifying app...${NC}"
codesign -dvv "$APP_NAME.app"

# Step 8: Create a simple DMG (optional)
echo -e "${YELLOW}Creating DMG...${NC}"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_NAME.app" \
    -ov -format UDZO \
    "AndroidDeviceManager.dmg"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}=== Build Complete! ===${NC}"
    echo -e "${GREEN}App: $APP_NAME.app${NC}"
    echo -e "${GREEN}DMG: AndroidDeviceManager.dmg${NC}"
    echo ""
    echo "To run the app:"
    echo "  open \"$APP_NAME.app\""
    echo ""
    echo "To install:"
    echo "  1. Open AndroidDeviceManager.dmg"
    echo "  2. Drag $APP_NAME to Applications folder"
else
    echo -e "${RED}DMG creation failed!${NC}"
fi
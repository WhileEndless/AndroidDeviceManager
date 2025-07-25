# macOS App Build and Package Guide
## Android Device Manager

### 1. Build Configuration

#### 1.1 Info.plist File
Check your Info.plist file and add the necessary information:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>com.androiddevicemanager.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Android Device Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.1</string>
    <key>CFBundleVersion</key>
    <string>121</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

### 2. Build Steps

#### 2.1 Build with Swift Package Manager
```bash
# Create release build
swift build -c release

# Check build output
ls -la .build/release/
```

#### 2.2 Create App Bundle
```bash
# Create app bundle directory structure
mkdir -p "Android Device Manager.app/Contents/MacOS"
mkdir -p "Android Device Manager.app/Contents/Resources"

# Copy executable
cp .build/release/AndroidDeviceManager "Android Device Manager.app/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "Android Device Manager.app/Contents/"

# Add icon (optional)
# cp AppIcon.icns "Android Device Manager.app/Contents/Resources/"
```

### 3. Code Signing

#### 3.1 Developer Certificate
If you have an Apple Developer account:
```bash
# Check certificate list
security find-identity -v -p codesigning

# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" "Android Device Manager.app"

# Verify signature
codesign -dvv "Android Device Manager.app"
```

#### 3.2 Ad-hoc Signing (without Developer account)
```bash
# Self-signed certificate
codesign --force --deep -s - "Android Device Manager.app"
```

### 4. Notarization (Apple Approval)

If you have a Developer account, notarization is recommended:

```bash
# Create zip for notarization
ditto -c -k --keepParent "Android Device Manager.app" "Android Device Manager.zip"

# Submit for notarization
xcrun notarytool submit "Android Device Manager.zip" \
    --apple-id "your@email.com" \
    --password "@keychain:AC_PASSWORD" \
    --team-id "TEAMID" \
    --wait

# Staple after notarization completes
xcrun stapler staple "Android Device Manager.app"
```

### 5. Creating DMG

#### 5.1 Using create-dmg (recommended)
```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "Android Device Manager" \
  --volicon "AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Android Device Manager.app" 175 190 \
  --hide-extension "Android Device Manager.app" \
  --app-drop-link 425 190 \
  "AndroidDeviceManager.dmg" \
  "Android Device Manager.app"
```

#### 5.2 Manual DMG Creation
```bash
# Create temporary directory
mkdir -p dmg-content
cp -R "Android Device Manager.app" dmg-content/

# Create DMG
hdiutil create -volname "Android Device Manager" \
  -srcfolder dmg-content \
  -ov -format UDZO \
  AndroidDeviceManager.dmg

# Cleanup
rm -rf dmg-content
```

### 6. Entitlements

If special system access is required, create entitlements.plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

Use during signing:
```bash
codesign --force --deep --sign "Developer ID" --entitlements entitlements.plist "Android Device Manager.app"
```

### 7. Automated Build Script

The project includes a `build_app.sh` script:

```bash
#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Building Android Device Manager..."

# Clean previous builds
rm -rf ".build"
rm -rf "Android Device Manager.app"
rm -f "AndroidDeviceManager.dmg"

# Build release version
echo "Building release version..."
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Create app bundle
echo "Creating app bundle..."
mkdir -p "Android Device Manager.app/Contents/MacOS"
mkdir -p "Android Device Manager.app/Contents/Resources"

cp .build/release/AndroidDeviceManager "Android Device Manager.app/Contents/MacOS/"
cp Info.plist "Android Device Manager.app/Contents/"

# Sign the app
echo "Signing app..."
codesign --force --deep -s - "Android Device Manager.app"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "Android Device Manager" \
  -srcfolder "Android Device Manager.app" \
  -ov -format UDZO \
  AndroidDeviceManager.dmg

echo -e "${GREEN}Build complete! DMG created: AndroidDeviceManager.dmg${NC}"
```

Make the script executable:
```bash
chmod +x build_app.sh
./build_app.sh
```

### 8. Testing

1. Test the created app:
```bash
open "Android Device Manager.app"
```

2. Test the DMG:
```bash
open AndroidDeviceManager.dmg
```

### 9. Distribution Options

#### 9.1 Direct Distribution
- Make DMG file downloadable from your website
- Distribute via GitHub Releases

#### 9.2 Mac App Store
- Requires Apple Developer account
- Create app in App Store Connect
- Upload with Xcode or Transporter

#### 9.3 Homebrew Cask
Create a Homebrew formula:
```ruby
cask "android-device-manager" do
  version "1.2.1"
  sha256 "SHA256_HASH"
  
  url "https://github.com/WhileEndless/android-device-manager/releases/download/v#{version}/AndroidDeviceManager.dmg"
  name "Android Device Manager"
  desc "macOS menu bar app for Android device management"
  homepage "https://github.com/WhileEndless/android-device-manager"
  
  app "Android Device Manager.app"
  
  zap trash: [
    "~/Library/Preferences/com.androiddevicemanager.plist",
  ]
end
```

### 10. Creating App Icon

Create an iconset for macOS app icon:
```bash
# Create icon directory
mkdir AppIcon.iconset

# Create icons in different sizes (starting from 1024x1024 PNG)
# Required sizes:
# 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024
# @1x and @2x versions for each

# Convert iconset to .icns format
iconutil -c icns AppIcon.iconset
```

### Troubleshooting

1. **"App is damaged" error**: May be due to Gatekeeper
```bash
xattr -cr "Android Device Manager.app"
```

2. **Notarization errors**: Requires Apple Developer account and app-specific password

3. **Code signing errors**: Check for valid certificate

### Resources
- [Apple Developer - Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [create-dmg Documentation](https://github.com/create-dmg/create-dmg)
- [Swift Package Manager](https://swift.org/package-manager/)
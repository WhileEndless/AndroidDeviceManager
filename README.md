# Android Device Manager

A powerful macOS menu bar application for managing Android devices via ADB (Android Debug Bridge).

[🇹🇷 Türkçe](README_TR.md)

## Version
**Current Version:** 1.1.0

## Features

### Device Management
- 📱 **Real-time Device Detection**: Automatically detects connected Android devices every 10 seconds
- ⚡ **Root Status Indicator**: Visual indicator shows if device has root access
- 🔒 **Authorization Status**: Clear indication of device authorization state
- 🔄 **Automatic Device Selection**: First connected device is automatically selected
- 📡 **USB & WiFi Support**: Works with both USB and wireless ADB connections

### Core Functionality

#### Screenshot Capture
- 📸 Take screenshots with one click
- 🖼️ Automatically opens in default image editor
- 📁 Organized storage in dedicated folder

#### Clipboard Integration
- 📋 Send macOS clipboard content to Android device (Cmd+V)
- ⌨️ Types content into currently focused field on Android

#### Shell Access
- 🖥️ Quick shell access with Terminal integration
- 🚀 Persistent shell sessions to avoid repeated root prompts
- 📝 Quick Commands window for frequently used commands

#### Port Forwarding
- 🔀 Forward and Reverse port forwarding support
- 🔄 Automatic reverse port 8080 setup on device connection
- 💾 Persistent port forwarding configurations

#### Frida Server Management (Root Required)
- 🔧 Download and install Frida servers
- 📦 Multiple architecture support
- 🔄 Version management

#### Logcat Viewer
- 📋 Real-time log viewing with color-coded levels
- 🔍 Filter by package name and log level
- 💾 Export logs to file
- 🖥️ Full-screen support
- ⌘A Select all text support

#### File Manager
- 📁 **Full Filesystem Navigation**: Browse entire Android filesystem with root support
- 🔄 **Drag & Drop Upload**: Drag files from Finder to upload with real-time progress
- 📥 **Batch Download**: Download multiple files with configurable destination
- ✏️ **File Operations**: Rename, delete, and manage files with context menu
- 🔍 **Real-time Search**: Instantly filter files in current directory
- 🗄️ **SQLite Integration**: Open .db files directly in Terminal with sqlite3
- 📊 **Column Sorting**: Sort by name, size, or modification date
- 🔙 **Navigation History**: Back/Forward buttons for easy navigation
- 🔗 **Symlink Support**: Seamless navigation through symbolic links

### User Interface
- 🎨 Clean, native macOS interface
- 📱 Device info window with detailed specifications
- ⚙️ Preferences for customization
- ℹ️ About window with version information

## System Requirements
- macOS 10.14 (Mojave) or later
- ADB (Android Debug Bridge) installed and in PATH
- Android device with USB debugging enabled

## Installation

### From DMG
1. Download the latest DMG from releases
2. Open the DMG file
3. Drag Android Device Manager to Applications
4. Launch from Applications folder

### From Source
```bash
git clone https://github.com/WhileEndless/AndroidDeviceManager.git
cd AndroidDeviceManager
swift build -c release
```

## Usage

1. **Connect your Android device** via USB or WiFi
2. **Enable USB debugging** on your Android device
3. **Launch Android Device Manager** - it will appear in your menu bar as 📱
4. Click the menu bar icon to access all features

### Keyboard Shortcuts
- **Cmd+S**: Take Screenshot
- **Cmd+V**: Send Clipboard to Device
- **Cmd+T**: Open Terminal
- **Cmd+R**: Refresh Devices
- **Cmd+,**: Open Preferences
- **Cmd+Q**: Quit

### In Logcat Viewer
- **Cmd+A**: Select All Text

## Building from Source

### Prerequisites
- Xcode 12.0 or later
- Swift 5.3 or later

### Build Steps
```bash
# Clone the repository
git clone https://github.com/WhileEndless/AndroidDeviceManager.git
cd AndroidDeviceManager

# Build the application
swift build -c release

# Or use the build script
./build_app.sh
```

## Architecture

### Project Structure
```
AndroidDeviceManager/
├── Sources/
│   ├── Models/          # Data models
│   ├── Managers/        # Business logic
│   ├── Services/        # ADB and shell services
│   ├── Windows/         # UI windows
│   └── StatusBarController.swift
├── Resources/           # Assets and resources
└── Tests/              # Unit tests
```

### Key Components
- **StatusBarController**: Main menu bar interface
- **DeviceManager**: Device discovery and management
- **ShellSessionManager**: Persistent shell session handling
- **ADBClient**: ADB command interface

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the LICENSE file for details.

## Development

This project was developed using Claude Code with the Opus model, demonstrating the capabilities of AI-assisted software development. The entire application architecture, implementation, and optimization were completed through collaborative development with Claude.

## Acknowledgments

- Built with Swift and Cocoa (AppKit)
- Uses Android Debug Bridge (ADB)
- Frida dynamic instrumentation toolkit support
- Developed with Claude Code (Opus model)

## Support

For issues and feature requests, please visit:
https://github.com/WhileEndless/AndroidDeviceManager/issues

---
© 2025 WhileEndless
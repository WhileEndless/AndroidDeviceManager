# Software Requirements Specification (SRS)
## Android Device Manager for macOS

### 1. Introduction

#### 1.1 Purpose
This document defines the software requirements for the Android Device Manager application for macOS. The application will provide various management and control functions by interacting with Android devices using Android Debug Bridge (ADB).

#### 1.2 Scope
**Product Name:** Android Device Manager for macOS  
**Product Code:** ADM-MAC  
**Version:** 1.2.1

The application will be developed as a system utility running in the macOS menu bar.

#### 1.3 Definitions and Abbreviations
- **ADB:** Android Debug Bridge
- **GUI:** Graphical User Interface
- **API:** Application Programming Interface
- **Frida:** Dynamic instrumentation toolkit

### 2. General Description

#### 2.1 Product Perspective
The application will be a standalone desktop application running on macOS. It will communicate with Android devices using ADB commands and provide a user-friendly interface.

#### 2.2 Product Functions
- Screenshot capture and save
- ADB shell access and quick commands
- Clipboard transfer (computer → device, text)
- Port forwarding management (forward and reverse)
- Frida server management (root required)
- Logcat viewing and filtering
- Device information display and export

#### 2.3 User Characteristics
- Android developers
- Security researchers
- Mobile application testers
- Technical users

#### 2.4 Constraints
- macOS 10.14 or higher required
- ADB must be installed on the system
- Android device with USB debugging enabled required
- Root access required for root-dependent functions

### 3. Specific Requirements

#### 3.1 Functional Requirements

##### FR-1: Device Management
- **FR-1.1:** The system shall detect connected Android devices automatically
- **FR-1.2:** The system shall display device status (authorized/unauthorized)
- **FR-1.3:** The system shall show root access availability
- **FR-1.4:** The system shall support multiple devices with switching capability
- **FR-1.5:** The system shall refresh device list every 10 seconds

##### FR-2: Screenshot Functionality
- **FR-2.1:** The system shall capture screenshots from the active device
- **FR-2.2:** The system shall save screenshots with timestamp filenames
- **FR-2.3:** The system shall open screenshots in the default image editor
- **FR-2.4:** The system shall provide a customizable screenshot directory

##### FR-3: Clipboard Integration
- **FR-3.1:** The system shall send macOS clipboard content to Android device
- **FR-3.2:** The system shall support Unicode and special characters
- **FR-3.3:** The system shall input text into the focused field on Android

##### FR-4: Shell Access
- **FR-4.1:** The system shall open Terminal.app with ADB shell
- **FR-4.2:** The system shall maintain persistent shell sessions
- **FR-4.3:** The system shall provide quick command execution
- **FR-4.4:** The system shall handle root sessions when available

##### FR-5: Port Forwarding
- **FR-5.1:** The system shall support forward port forwarding (Local → Device)
- **FR-5.2:** The system shall support reverse port forwarding (Device → Local)
- **FR-5.3:** The system shall persist port forwarding rules
- **FR-5.4:** The system shall auto-setup port 8080 on device connection
- **FR-5.5:** The system shall detect port conflicts

##### FR-6: Frida Server Management
- **FR-6.1:** The system shall list installed Frida servers (root only)
- **FR-6.2:** The system shall start/stop Frida servers
- **FR-6.3:** The system shall enforce single server instance
- **FR-6.4:** The system shall detect architecture compatibility

##### FR-7: Logcat Viewer
- **FR-7.1:** The system shall stream real-time logs
- **FR-7.2:** The system shall filter by package name
- **FR-7.3:** The system shall filter by log level (V/D/I/W/E)
- **FR-7.4:** The system shall export logs to file
- **FR-7.5:** The system shall support full-screen mode
- **FR-7.6:** The system shall handle up to 50,000 log entries

##### FR-8: Device Information
- **FR-8.1:** The system shall display detailed device specifications
- **FR-8.2:** The system shall show system information
- **FR-8.3:** The system shall display hardware details
- **FR-8.4:** The system shall provide export functionality

#### 3.2 Non-Functional Requirements

##### NFR-1: Performance
- **NFR-1.1:** Device detection shall complete within 2 seconds
- **NFR-1.2:** Screenshot capture shall complete within 3 seconds
- **NFR-1.3:** The application shall use less than 100MB RAM in idle state
- **NFR-1.4:** CPU usage shall remain below 5% when idle

##### NFR-2: Usability
- **NFR-2.1:** All functions shall be accessible within 2 clicks
- **NFR-2.2:** The application shall provide keyboard shortcuts
- **NFR-2.3:** Error messages shall be clear and actionable
- **NFR-2.4:** The UI shall follow macOS design guidelines

##### NFR-3: Reliability
- **NFR-3.1:** The application shall handle device disconnections gracefully
- **NFR-3.2:** The application shall recover from ADB crashes
- **NFR-3.3:** Settings shall persist across application restarts
- **NFR-3.4:** The application shall validate all user inputs

##### NFR-4: Security
- **NFR-4.1:** The application shall not store sensitive device data
- **NFR-4.2:** File operations shall respect macOS permissions
- **NFR-4.3:** The application shall not transmit data over network
- **NFR-4.4:** Root operations shall require explicit user action

##### NFR-5: Compatibility
- **NFR-5.1:** Support macOS 10.14 (Mojave) and later
- **NFR-5.2:** Support Android 4.0+ devices
- **NFR-5.3:** Work with standard ADB installations
- **NFR-5.4:** Support both Intel and Apple Silicon Macs

### 4. External Interface Requirements

#### 4.1 User Interfaces
- Menu bar icon with dropdown menu
- Modal windows for complex operations
- Native macOS controls and styling
- System notifications for events

#### 4.2 Hardware Interfaces
- USB connection for Android devices
- WiFi connection for wireless ADB
- File system access for screenshots and logs

#### 4.3 Software Interfaces
- Android Debug Bridge (ADB) command-line tool
- macOS Terminal.app for shell access
- Default image editor for screenshots
- macOS notification system

### 5. System Architecture

#### 5.1 Components
- **StatusBarController:** Main menu bar interface
- **DeviceManager:** Device detection and management
- **ADBClient:** ADB command execution
- **ShellSessionManager:** Persistent shell handling
- **Window Controllers:** UI window management

#### 5.2 Data Flow
1. User interaction → Menu selection
2. Controller processing → Manager invocation
3. ADB command execution → Device communication
4. Response processing → UI update
5. User notification → Status display

### 6. Quality Attributes

#### 6.1 Maintainability
- Modular architecture with clear separation of concerns
- Comprehensive code documentation
- Unit test coverage for critical functions
- Version control with meaningful commits

#### 6.2 Portability
- Swift Package Manager for dependency management
- Standard macOS APIs for system integration
- Minimal external dependencies
- Clear build and packaging instructions

### 7. Appendices

#### 7.1 References
- [Android Debug Bridge Documentation](https://developer.android.com/studio/command-line/adb)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

#### 7.2 Version History
- v1.0.0 - Initial release (2025-01-20)
- v1.2.1 - Terminal integration and File Manager enhancements (2025-01-25)
- v1.1.0 - Comprehensive File Manager with advanced features (2025-01-25)
- v1.0.1 - Performance improvements and bug fixes (2025-01-25)
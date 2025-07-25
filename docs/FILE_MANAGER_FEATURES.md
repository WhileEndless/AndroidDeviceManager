# File Manager Features

## Overview
The File Manager is a comprehensive file browsing and management tool for Android devices, integrated into Android Device Manager v1.1.0. It provides a native macOS interface for navigating, managing, and transferring files on Android devices via ADB.

## Key Features

### 1. Directory Navigation
- **Browse entire filesystem** starting from root (/)
- **Symlink support** with automatic resolution
- **Navigation history** with Back/Forward buttons
- **Parent directory** navigation with Up button
- **Home button** to quickly return to root
- **Path field** for direct navigation by typing paths
- **Real-time search** within current directory

### 2. File Operations

#### Download (Pull)
- Single and multiple file selection support
- Downloads to configurable directory (default: ~/Downloads)
- **Root file support** via temporary copy mechanism
- Progress indicator during download
- Opens download folder in Finder upon completion

#### Upload (Push)
- **Drag & drop** support from Finder
- Context menu "Upload Files Here..." option
- **Real-time progress window** showing:
  - Upload speed (MB/s)
  - Progress percentage
  - Time remaining estimation
  - Bytes transferred
- Multiple file upload support
- Automatic permission setting in root directories

#### Delete
- Single and multiple selection support
- Confirmation dialog with file list
- Safe deletion with proper error handling

#### Rename
- In-place file renaming
- Input validation
- Instant refresh after rename

### 3. Special File Type Support

#### SQLite Database Files (.db)
- "Open with SQLite3" context menu option
- Downloads to temporary location
- Opens in Terminal with sqlite3
- Automatic cleanup after use

### 4. User Interface

#### Table View
- **Sortable columns**: Name, Size, Modified Date
- **Column resizing** support
- **Multiple selection** with Cmd+Click and Shift+Click
- **Icon display** for file types
- **Text truncation** with tooltips for long filenames

#### Context Menu (Right-Click)
- Dynamic menu based on selection
- Single file: Rename, Download, Delete, Special actions
- Multiple files: Download X files, Delete X items
- Empty space: Upload Files Here...

#### Toolbar
- Navigation buttons (Back, Forward, Up, Home)
- Editable path field
- Search field with instant filtering
- Refresh button
- Progress indicator

### 5. Performance Features
- **Persistent shell sessions** for fast command execution
- **Efficient ls parsing** with custom parser
- **Asynchronous operations** to keep UI responsive
- **Session reuse** across File Manager windows

### 6. Root Access Support
- Automatic detection of root requirement
- Seamless switching between regular and root shell
- Special handling for protected directories:
  - /data/data
  - /system
  - /data/app
  - /data/local

### 7. Preferences Integration
- Configurable download directory
- Settings persist across sessions
- Available in Preferences window

## Technical Implementation

### Architecture
- **MVC Pattern**: Separate View Controller, Models, and Services
- **Session Management**: Reuses ShellSessionManager for efficiency
- **Thread Safety**: All file operations on background queues
- **Error Handling**: Comprehensive error reporting to users

### Key Components
1. `FileListViewController`: Main UI and logic
2. `FileItem`: Model for file/directory representation
3. `LSParser`: Parses Android `ls -lah` output
4. `FileManagerWindow`: Window controller
5. `FileUploadProgressWindow`: Upload progress UI

### Integration Points
- Uses existing `ADBClient` for all device communication
- Leverages `ShellSessionManager` for persistent connections
- Integrates with `Preferences` for settings
- Appears in status bar menu

## Security Considerations
- All file paths properly escaped
- Temporary files cleaned up after use
- Root access only used when necessary
- No hardcoded credentials or sensitive data

## Future Enhancements
- File preview for images and text
- Batch rename operations
- File compression/extraction
- Network file transfer
- File property editor
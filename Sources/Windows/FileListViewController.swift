//
//  FileListViewController.swift
//  AndroidDeviceManager
//
//  Created by ADB File Manager on 2025-01-25.
//

import Cocoa

class FileListViewController: NSViewController {
    
    // MARK: - Properties
    private let device: Device
    private let adbClient: ADBClient
    private var currentPath: String = "/"
    private var items: [FileItem] = []
    private var hasRoot: Bool = false
    
    // Sorting properties
    private var sortDescriptor: NSSortDescriptor?
    private var sortedItems: [FileItem] = []
    
    // Search
    private var searchText: String = ""
    private var filteredItems: [FileItem] = []
    
    // Navigation history
    private var navigationHistory: [String] = []
    private var currentHistoryIndex: Int = -1
    
    
    // MARK: - UI Elements
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let pathLabel = NSTextField()
    private let statusLabel = NSTextField()
    private let progressIndicator = NSProgressIndicator()
    
    // Toolbar buttons
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let upButton = NSButton()
    private let homeButton = NSButton()
    private let refreshButton = NSButton()
    private let searchField = NSSearchField()
    
    // MARK: - Init
    init(device: Device, adbClient: ADBClient) {
        self.device = device
        self.adbClient = adbClient
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkRootAccess()
        // Initial load should add to history
        loadDirectory(currentPath)
        // Initially disable navigation buttons
        backButton.isEnabled = false
        forwardButton.isEnabled = false
        // Update up button state
        updateUpButton()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Remove focus from path field
        view.window?.makeFirstResponder(tableView)
    }
    
    
    deinit {
        // Don't close the session - keep it alive for better performance
        // Sessions will be managed by ShellSessionManager lifecycle
        print("[FileManager] Window closed, keeping session alive for device: \(device.deviceId)")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Toolbar
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        // Navigation buttons
        setupButton(backButton, title: "←", action: #selector(goBack))
        setupButton(forwardButton, title: "→", action: #selector(goForward))
        setupButton(upButton, title: "↑", action: #selector(goUp))
        setupButton(homeButton, title: "🏠", action: #selector(goHome))
        
        toolbar.addSubview(backButton)
        toolbar.addSubview(forwardButton)
        toolbar.addSubview(upButton)
        toolbar.addSubview(homeButton)
        
        // Path field
        pathLabel.isEditable = true
        pathLabel.isBordered = true
        pathLabel.bezelStyle = .roundedBezel
        pathLabel.stringValue = currentPath
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.target = self
        pathLabel.action = #selector(pathFieldDidEndEditing(_:))
        toolbar.addSubview(pathLabel)
        
        // Search field
        searchField.placeholderString = "Search in current directory..."
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchFieldDidChange(_:))
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        toolbar.addSubview(searchField)
        
        // Action buttons
        setupButton(refreshButton, title: "🔄", action: #selector(refresh))
        toolbar.addSubview(refreshButton)
        
        // Progress indicator
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(progressIndicator)
        
        // Table view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(doubleClick)
        tableView.target = self
        tableView.rowSizeStyle = .default
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
        
        // Setup context menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        
        // Columns
        let iconColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconColumn.title = ""
        iconColumn.width = 30
        iconColumn.minWidth = 30
        iconColumn.maxWidth = 30
        tableView.addTableColumn(iconColumn)
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 300
        nameColumn.minWidth = 100
        // No max width limit for name column - it can expand as much as needed
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
        tableView.addTableColumn(nameColumn)
        
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 80
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 150
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "sizeInBytes", ascending: true)
        tableView.addTableColumn(sizeColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("modified"))
        dateColumn.title = "Modified"
        dateColumn.width = 150
        dateColumn.minWidth = 100
        dateColumn.maxWidth = 250
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: "displayDate", ascending: true)
        tableView.addTableColumn(dateColumn)
        
        let permissionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("permissions"))
        permissionsColumn.title = "Permissions"
        permissionsColumn.width = 100
        permissionsColumn.minWidth = 80
        permissionsColumn.maxWidth = 200
        tableView.addTableColumn(permissionsColumn)
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        // Register for drag & drop
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        
        // Status bar
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.stringValue = "Loading..."
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            // Toolbar
            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            toolbar.heightAnchor.constraint(equalToConstant: 40),
            
            // Navigation buttons
            backButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 5),
            forwardButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 30),
            
            upButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 5),
            upButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            upButton.widthAnchor.constraint(equalToConstant: 30),
            
            homeButton.leadingAnchor.constraint(equalTo: upButton.trailingAnchor, constant: 5),
            homeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            homeButton.widthAnchor.constraint(equalToConstant: 30),
            
            // Path field
            pathLabel.leadingAnchor.constraint(equalTo: homeButton.trailingAnchor, constant: 10),
            pathLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            // Search field
            searchField.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),
            
            // Action buttons
            refreshButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            refreshButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 30),
            
            progressIndicator.trailingAnchor.constraint(equalTo: searchField.leadingAnchor, constant: -10),
            progressIndicator.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            pathLabel.trailingAnchor.constraint(equalTo: progressIndicator.leadingAnchor, constant: -10),
            
            // Table view
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            // Status bar
            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 5),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - Actions
    @objc private func goBack() {
        guard currentHistoryIndex > 0 else { return }
        currentHistoryIndex -= 1
        let path = navigationHistory[currentHistoryIndex]
        loadDirectory(path, addToHistory: false)
        updateNavigationButtons()
        updateUpButton()
    }
    
    @objc private func goForward() {
        guard currentHistoryIndex < navigationHistory.count - 1 else { return }
        currentHistoryIndex += 1
        let path = navigationHistory[currentHistoryIndex]
        loadDirectory(path, addToHistory: false)
        updateNavigationButtons()
        updateUpButton()
    }
    
    @objc private func goUp() {
        guard currentPath != "/" else { return }
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != currentPath {
            loadDirectory(parentPath)
        } else if currentPath != "/" {
            // If deletingLastPathComponent didn't work properly, go to root
            loadDirectory("/")
        }
    }
    
    @objc private func goHome() {
        loadDirectory("/")
    }
    
    @objc private func refresh() {
        loadDirectory(currentPath)
    }
    
    @objc private func searchFieldDidChange(_ sender: NSSearchField) {
        searchText = sender.stringValue
        filterAndSortItems()
        tableView.reloadData()
    }
    
    @objc private func pathFieldDidEndEditing(_ sender: NSTextField) {
        let newPath = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newPath.isEmpty && newPath != currentPath {
            loadDirectory(newPath)
        } else {
            // Restore current path if empty or unchanged
            sender.stringValue = currentPath
        }
    }
    
    @objc private func doubleClick() {
        let row = tableView.clickedRow
        guard row >= 0 && row < sortedItems.count else { return }
        
        let item = sortedItems[row]
        if item.isDirectory || item.isSymlink {
            // For symlinks, follow the link target
            if item.isSymlink, let target = item.linkTarget {
                print("[FileManager] Following symlink: \(item.name) -> \(target)")
                loadDirectory(target)
            } else {
                loadDirectory(item.fullPath)
            }
        } else if item.name.hasSuffix(".apk") {
            // TODO: Implement APK installation
        }
    }
    
    // MARK: - File Operations
    private func checkRootAccess() {
        // Use device's already checked root status instead of checking again
        hasRoot = device.isRooted
        print("[FileManager] Device root status: \(hasRoot)")
    }
    
    private func loadDirectory(_ path: String, addToHistory: Bool = true) {
        progressIndicator.startAnimation(nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let startTime = Date()
            
            // First check if path is a symlink to a directory
            let command = "cd '\(path)' && ls -lah; echo \"__EOF__\""
            
            print("[FileManager] Executing command: \(command)")
            
            let result: CommandResult
            if self.needsRoot(path) && self.hasRoot {
                // Use root session for directories that need it
                result = self.adbClient.shellAsRoot(
                    command: command,
                    deviceId: self.device.deviceId,
                    timeout: 2.0
                )
            } else {
                result = self.adbClient.shell(
                    command: command,
                    deviceId: self.device.deviceId,
                    persistent: true,
                    timeout: 2.0
                )
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("[FileManager] Command completed in \(String(format: "%.2f", elapsed))s")
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                
                if result.isSuccess {
                    self.currentPath = path
                    self.pathLabel.stringValue = path
                    self.items = LSParser.parse(output: result.output, currentPath: path)
                    // Clear search when directory changes
                    self.searchField.stringValue = ""
                    self.searchText = ""
                    self.filterAndSortItems()
                    self.tableView.reloadData()
                    self.updateStatus()
                    
                    // Add to navigation history
                    if addToHistory {
                        self.addToNavigationHistory(path)
                    }
                    self.updateNavigationButtons()
                    self.updateUpButton()
                } else {
                    if let error = LSParser.parseError(result.output) {
                        self.showError(error)
                    } else {
                        self.showError("Failed to load directory")
                    }
                }
            }
        }
    }
    
    private func needsRoot(_ path: String) -> Bool {
        let rootPaths = ["/data/data", "/system", "/data/app", "/data/local"]
        return rootPaths.contains { path.hasPrefix($0) }
    }
    
    private func updateStatus() {
        let fileCount = items.filter { $0.isFile }.count
        let dirCount = items.filter { $0.isDirectory }.count
        let rootStatus = hasRoot ? "✓" : "✗"
        statusLabel.stringValue = "\(items.count) items (\(dirCount) folders, \(fileCount) files) | Root: \(rootStatus)"
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Filtering and Sorting
    private func filterAndSortItems() {
        // First filter items if search is active
        let itemsToSort: [FileItem]
        if searchText.isEmpty {
            itemsToSort = items
        } else {
            itemsToSort = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Then sort the filtered items
        sortedItems = itemsToSort.sorted { item1, item2 in
            // Directories always come before files
            if item1.isDirectory && !item2.isDirectory {
                return true
            } else if !item1.isDirectory && item2.isDirectory {
                return false
            }
            
            // If both are same type, use sort descriptor or default to name
            if let descriptor = sortDescriptor {
                if descriptor.key == "name" {
                    let result = item1.name.localizedCaseInsensitiveCompare(item2.name)
                    return descriptor.ascending ? (result == .orderedAscending) : (result == .orderedDescending)
                } else if descriptor.key == "sizeInBytes" {
                    return descriptor.ascending ? (item1.sizeInBytes < item2.sizeInBytes) : (item1.sizeInBytes > item2.sizeInBytes)
                } else if descriptor.key == "displayDate" {
                    let result = item1.displayDate.compare(item2.displayDate)
                    return descriptor.ascending ? (result == .orderedAscending) : (result == .orderedDescending)
                }
            }
            
            // Default: sort by name
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
    }
    
    // MARK: - Navigation History
    private func addToNavigationHistory(_ path: String) {
        // Remove any forward history if we're not at the end
        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)..<navigationHistory.count)
        }
        
        // Add new path
        navigationHistory.append(path)
        currentHistoryIndex = navigationHistory.count - 1
        
        // Limit history size
        if navigationHistory.count > 50 {
            navigationHistory.removeFirst()
            currentHistoryIndex -= 1
        }
    }
    
    private func updateNavigationButtons() {
        backButton.isEnabled = currentHistoryIndex > 0
        forwardButton.isEnabled = currentHistoryIndex < navigationHistory.count - 1
    }
    
    private func updateUpButton() {
        upButton.isEnabled = currentPath != "/"
    }
    
    // MARK: - File Operations (Context Menu)
    @objc private func renameFile(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? FileItem else { return }
        
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.informativeText = "Enter new name for '\(item.name)':"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = item.name
        alert.accessoryView = input
        
        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let newName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !newName.isEmpty && newName != item.name {
                    self.performRename(item: item, newName: newName)
                }
            }
        }
    }
    
    private func performRename(item: FileItem, newName: String) {
        let oldPath = item.fullPath
        let newPath = (currentPath as NSString).appendingPathComponent(newName)
        let command = "mv '\(oldPath)' '\(newPath)'"
        
        let result = adbClient.shell(
            command: command,
            deviceId: device.deviceId,
            persistent: true
        )
        
        if result.isSuccess {
            refresh()
        } else {
            showError("Failed to rename file: \(result.error)")
        }
    }
    
    @objc private func downloadFile(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? FileItem else { return }
        downloadFiles([item])
    }
    
    @objc private func downloadMultipleFiles(_ sender: NSMenuItem) {
        guard let items = sender.representedObject as? [FileItem] else { return }
        downloadFiles(items)
    }
    
    private func downloadFiles(_ items: [FileItem]) {
        let downloadDir = Preferences.shared.downloadDirectory
        
        // Create download directory if it doesn't exist
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: downloadDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showError("Failed to create download directory: \(error)")
            return
        }
        
        progressIndicator.startAnimation(nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var successCount = 0
            var failedFiles: [String] = []
            
            for item in items {
                let localPath = (downloadDir as NSString).appendingPathComponent(item.name)
                
                // For files that might need root access, copy to temp location first
                let needsRootCopy = self.needsRoot(item.fullPath) && self.hasRoot
                let remotePath: String
                
                if needsRootCopy {
                    // Create a temporary file path
                    let tempPath = "/sdcard/Download/temp_\(UUID().uuidString)_\(item.name)"
                    
                    // Ensure directory exists and copy file to accessible location using root
                    let copyCommand = "mkdir -p /sdcard/Download && cp '\(item.fullPath)' '\(tempPath)' && chmod 644 '\(tempPath)'"
                    let copyResult = self.adbClient.shellAsRoot(
                        command: copyCommand,
                        deviceId: self.device.deviceId
                    )
                    
                    if !copyResult.isSuccess {
                        failedFiles.append(item.name)
                        continue
                    }
                    
                    remotePath = tempPath
                } else {
                    remotePath = item.fullPath
                }
                
                // Now pull the file
                let result = self.adbClient.pull(
                    remotePath: remotePath,
                    localPath: localPath,
                    deviceId: self.device.deviceId
                )
                
                // Clean up temp file if we created one
                if needsRootCopy {
                    _ = self.adbClient.shell(
                        command: "rm -f '\(remotePath)'",
                        deviceId: self.device.deviceId
                    )
                }
                
                if result.isSuccess {
                    successCount += 1
                } else {
                    failedFiles.append(item.name)
                }
            }
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                
                if failedFiles.isEmpty {
                    // Open download directory in Finder
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadDir)
                } else {
                    self.showError("Failed to download \(failedFiles.count) files:\n\(failedFiles.joined(separator: "\n"))")
                }
            }
        }
    }
    
    @objc private func deleteFiles(_ sender: NSMenuItem) {
        guard let items = sender.representedObject as? [FileItem] else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        
        if items.count == 1 {
            alert.messageText = "Delete '\(items[0].name)'?"
            alert.informativeText = "This action cannot be undone."
        } else {
            alert.messageText = "Delete \(items.count) items?"
            alert.informativeText = "This action cannot be undone. The following items will be deleted:\n\n\(items.map { $0.name }.joined(separator: "\n"))"
        }
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                self.performDelete(items: items)
            }
        }
    }
    
    private func performDelete(items: [FileItem]) {
        progressIndicator.startAnimation(nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var failedItems: [String] = []
            
            for item in items {
                let command = item.isDirectory ? "rm -rf '\(item.fullPath)'" : "rm -f '\(item.fullPath)'"
                let result = self.adbClient.shell(
                    command: command,
                    deviceId: self.device.deviceId,
                    persistent: true
                )
                
                if !result.isSuccess {
                    failedItems.append(item.name)
                }
            }
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                
                if failedItems.isEmpty {
                    self.refresh()
                } else {
                    self.showError("Failed to delete \(failedItems.count) items:\n\(failedItems.joined(separator: "\n"))")
                    self.refresh() // Refresh anyway to show what was deleted
                }
            }
        }
    }
    
    @objc private func openWithSQLite(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? FileItem else { return }
        
        progressIndicator.startAnimation(nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create temporary directory
            let tempDir = NSTemporaryDirectory().appending("AndroidDeviceManager/sqlite/")
            let tempFile = tempDir.appending(item.name)
            
            do {
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    self.progressIndicator.stopAnimation(nil)
                    self.showError("Failed to create temporary directory: \(error)")
                }
                return
            }
            
            // For files that might need root access, copy to temp location first
            let needsRootCopy = self.needsRoot(item.fullPath) && self.hasRoot
            let remotePath: String
            
            if needsRootCopy {
                // Create a temporary file path
                let tempRemotePath = "/sdcard/Download/temp_\(UUID().uuidString)_\(item.name)"
                
                // Ensure directory exists and copy file to accessible location using root
                let copyCommand = "mkdir -p /sdcard/Download && cp '\(item.fullPath)' '\(tempRemotePath)' && chmod 644 '\(tempRemotePath)'"
                let copyResult = self.adbClient.shellAsRoot(
                    command: copyCommand,
                    deviceId: self.device.deviceId
                )
                
                if !copyResult.isSuccess {
                    DispatchQueue.main.async {
                        self.progressIndicator.stopAnimation(nil)
                        self.showError("Failed to copy database file: \(copyResult.error)")
                    }
                    return
                }
                
                remotePath = tempRemotePath
            } else {
                remotePath = item.fullPath
            }
            
            // Download the file
            let result = self.adbClient.pull(
                remotePath: remotePath,
                localPath: tempFile,
                deviceId: self.device.deviceId
            )
            
            // Clean up temp file if we created one
            if needsRootCopy {
                _ = self.adbClient.shell(
                    command: "rm -f '\(remotePath)'",
                    deviceId: self.device.deviceId
                )
            }
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                
                if result.isSuccess {
                    // Open Terminal with sqlite3
                    let script = """
                    tell application "Terminal"
                        activate
                        set newTab to do script "cd '\(tempDir)' && sqlite3 '\(tempFile)'; rm -f '\(tempFile)'"
                    end tell
                    """
                    
                    if let appleScript = NSAppleScript(source: script) {
                        var error: NSDictionary?
                        appleScript.executeAndReturnError(&error)
                        
                        if let error = error {
                            self.showError("Failed to open Terminal: \(error)")
                        }
                    }
                } else {
                    self.showError("Failed to download database file: \(result.error)")
                }
            }
        }
    }
}

// MARK: - NSTableViewDataSource
extension FileListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sortedItems.count
    }
}


// MARK: - NSMenuDelegate
extension FileListViewController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Check if we need to update selection based on right-click location
        if let event = NSApp.currentEvent, event.type == .rightMouseDown {
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            
            if row >= 0 && !tableView.selectedRowIndexes.contains(row) {
                // Select the row that was right-clicked if it's not already selected
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }
}

// MARK: - NSTableViewDelegate
extension FileListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < sortedItems.count else { return nil }
        let item = sortedItems[row]
        
        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let text: String
        
        switch cellIdentifier.rawValue {
        case "icon":
            text = item.icon
        case "name":
            text = item.name
        case "size":
            text = item.isDirectory ? "--" : item.sizeString
        case "modified":
            text = item.displayDate
        case "permissions":
            text = item.permissions
        default:
            text = ""
        }
        
        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            // Update line break mode for existing cells
            cell.textField?.lineBreakMode = .byTruncatingTail
            cell.textField?.cell?.truncatesLastVisibleLine = true
            cell.textField?.maximumNumberOfLines = 1
            // Add tooltip for long names
            if cellIdentifier.rawValue == "name" && text.count > 30 {
                cell.textField?.toolTip = text
            }
            return cell
        }
        
        let cell = NSTableCellView()
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.stringValue = text
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Set line break mode to truncate with ellipsis
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.truncatesLastVisibleLine = true
        textField.maximumNumberOfLines = 1
        
        // Add tooltip for full text
        if cellIdentifier.rawValue == "name" && text.count > 30 {
            textField.toolTip = text
        }
        
        cell.addSubview(textField)
        cell.textField = textField
        
        NSLayoutConstraint.activate([
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else {
            sortDescriptor = nil
            filterAndSortItems()
            tableView.reloadData()
            return
        }
        
        sortDescriptor = descriptor
        filterAndSortItems()
        tableView.reloadData()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // Get selected items
        let selectedRows = tableView.selectedRowIndexes
        let selectedItems = selectedRows.compactMap { row in
            row < sortedItems.count ? sortedItems[row] : nil
        }
        
        // Build menu based on selection (even if empty)
        buildContextMenu(menu: menu, for: selectedItems)
    }
    
    private func buildContextMenu(menu: NSMenu, for selectedItems: [FileItem]) {
        // Upload option (when right-clicking on empty space or directory)
        if selectedItems.isEmpty || (selectedItems.count == 1 && selectedItems[0].isDirectory) {
            let uploadItem = NSMenuItem(title: "Upload Files Here...", action: #selector(uploadFilesHere(_:)), keyEquivalent: "")
            uploadItem.target = self
            menu.addItem(uploadItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // Single selection options
        if selectedItems.count == 1 {
            let item = selectedItems[0]
            
            if !item.isDirectory {
                // Rename
                let renameItem = NSMenuItem(title: "Rename", action: #selector(renameFile(_:)), keyEquivalent: "")
                renameItem.target = self
                renameItem.representedObject = item
                menu.addItem(renameItem)
                
                menu.addItem(NSMenuItem.separator())
                
                // Download
                let downloadItem = NSMenuItem(title: "Download", action: #selector(downloadFile(_:)), keyEquivalent: "")
                downloadItem.target = self
                downloadItem.representedObject = item
                menu.addItem(downloadItem)
                
                // Special options for specific file types
                if item.name.hasSuffix(".db") {
                    let sqliteItem = NSMenuItem(title: "Open with SQLite3", action: #selector(openWithSQLite(_:)), keyEquivalent: "")
                    sqliteItem.target = self
                    sqliteItem.representedObject = item
                    menu.addItem(sqliteItem)
                }
                
                menu.addItem(NSMenuItem.separator())
            }
        } else {
            // Multiple selection - only download for files
            let onlyFiles = selectedItems.filter { !$0.isDirectory }
            if !onlyFiles.isEmpty {
                let downloadItem = NSMenuItem(title: "Download \(onlyFiles.count) files", action: #selector(downloadMultipleFiles(_:)), keyEquivalent: "")
                downloadItem.target = self
                downloadItem.representedObject = onlyFiles
                menu.addItem(downloadItem)
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Delete (works for both single and multiple selection)
        let deleteTitle = selectedItems.count == 1 ? "Delete" : "Delete \(selectedItems.count) items"
        let deleteItem = NSMenuItem(title: deleteTitle, action: #selector(deleteFiles(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = selectedItems
        menu.addItem(deleteItem)
    }
    
    // MARK: - Drag & Drop
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        // Only allow drops between rows (on folders) or at the end (current directory)
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !items.isEmpty else {
            return []
        }
        
        // Check if all items are files (not directories)
        let fileManager = FileManager.default
        for url in items {
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return []
            }
        }
        
        return .copy
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else {
            return false
        }
        
        // Filter to only files that exist
        let fileManager = FileManager.default
        let filesToUpload = urls.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
        
        guard !filesToUpload.isEmpty else { return false }
        
        // Determine target directory
        let targetPath: String
        if row < sortedItems.count && dropOperation == .on {
            let item = sortedItems[row]
            if item.isDirectory {
                targetPath = item.fullPath
            } else {
                targetPath = currentPath
            }
        } else {
            targetPath = currentPath
        }
        
        // Start upload
        uploadFiles(filesToUpload, to: targetPath)
        
        return true
    }
    
    private func uploadFiles(_ files: [URL], to remotePath: String) {
        let progressWindow = FileUploadProgressWindow()
        progressWindow.showWindow(nil)
        
        var uploadCancelled = false
        progressWindow.onCancel = {
            uploadCancelled = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var successCount = 0
            var failedFiles: [String] = []
            
            for (index, fileURL) in files.enumerated() {
                if uploadCancelled { break }
                
                let fileName = fileURL.lastPathComponent
                let remoteFilePath = (remotePath as NSString).appendingPathComponent(fileName)
                
                // Update progress window
                progressWindow.updateFileName("Uploading: \(fileName) (\(index + 1)/\(files.count))")
                
                // Get file size
                let fileSize = self.getFileSize(at: fileURL)
                
                // Monitor upload progress
                var lastProgressUpdate = Date()
                var lastBytesTransferred: Int64 = 0
                
                // Create a temporary script to monitor file size on device
                let tempScriptPath = "/tmp/upload_monitor_\(UUID().uuidString).sh"
                let monitorScript = """
                #!/bin/sh
                while [ -f "$1" ]; do
                    size=$(stat -c%s "$1" 2>/dev/null || echo 0)
                    echo $size
                    sleep 0.5
                done
                """
                
                // Write monitor script
                try? monitorScript.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
                
                // Start monitoring in background
                let monitorQueue = DispatchQueue(label: "upload.monitor")
                
                class MonitorState {
                    var shouldStop = false
                    let lock = NSLock()
                    
                    func stop() {
                        lock.lock()
                        shouldStop = true
                        lock.unlock()
                    }
                    
                    func checkShouldStop() -> Bool {
                        lock.lock()
                        let result = shouldStop
                        lock.unlock()
                        return result
                    }
                }
                
                let monitorState = MonitorState()
                
                monitorQueue.async {
                    while !monitorState.checkShouldStop() && !uploadCancelled {
                        // Check remote file size
                        let sizeResult = self.adbClient.shell(
                            command: "stat -c%s '\(remoteFilePath)' 2>/dev/null || echo 0",
                            deviceId: self.device.deviceId,
                            persistent: true,
                            timeout: 1.0
                        )
                        
                        if let sizeStr = sizeResult.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines).first,
                           let bytesTransferred = Int64(sizeStr) {
                            
                            let now = Date()
                            let timeDelta = now.timeIntervalSince(lastProgressUpdate)
                            
                            if timeDelta > 0.5 { // Update every 0.5 seconds
                                let bytesDelta = bytesTransferred - lastBytesTransferred
                                let speed = Double(bytesDelta) / timeDelta
                                let progress = fileSize > 0 ? (Double(bytesTransferred) / Double(fileSize)) * 100.0 : 0
                                
                                progressWindow.updateProgress(progress, bytesTransferred: bytesTransferred, totalBytes: fileSize, speed: speed)
                                
                                lastProgressUpdate = now
                                lastBytesTransferred = bytesTransferred
                            }
                        }
                        
                        Thread.sleep(forTimeInterval: 0.5)
                    }
                }
                
                // Perform the actual upload
                let result = self.adbClient.push(
                    localPath: fileURL.path,
                    remotePath: remoteFilePath,
                    deviceId: self.device.deviceId
                )
                
                // Stop monitoring
                monitorState.stop()
                
                // Clean up temp script
                try? FileManager.default.removeItem(atPath: tempScriptPath)
                
                if result.isSuccess {
                    successCount += 1
                    // Set proper permissions if we have root
                    if self.hasRoot && self.needsRoot(remotePath) {
                        _ = self.adbClient.shellAsRoot(
                            command: "chmod 644 '\(remoteFilePath)'",
                            deviceId: self.device.deviceId
                        )
                    }
                } else {
                    failedFiles.append(fileName)
                }
            }
            
            DispatchQueue.main.async {
                progressWindow.window?.close()
                
                if !uploadCancelled {
                    if failedFiles.isEmpty {
                        // All files uploaded successfully
                        self.refresh()
                    } else {
                        self.showError("Failed to upload \(failedFiles.count) files:\n\(failedFiles.joined(separator: "\n"))")
                        self.refresh() // Refresh anyway to show what was uploaded
                    }
                }
            }
        }
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    @objc private func uploadFilesHere(_ sender: NSMenuItem) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Upload"
        openPanel.message = "Select files to upload to the current directory"
        
        openPanel.beginSheetModal(for: view.window!) { [weak self] response in
            if response == .OK {
                self?.uploadFiles(openPanel.urls, to: self?.currentPath ?? "/")
            }
        }
    }
}


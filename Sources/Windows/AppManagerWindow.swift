import Cocoa

class AppManagerWindow: NSWindowController {
    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var systemAppsCheckbox: NSButton!
    private var exportButton: NSButton!
    private var openInFileManagerButton: NSButton!
    
    private var appManager: AppManager?
    private var device: Device
    private var apps: [AppPackage] = []
    private var filteredApps: [AppPackage] = []
    private var isLoading = false
    
    init(device: Device) {
        self.device = device
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "App Manager"
        window.center()
        
        super.init(window: window)
        
        self.appManager = AppManager(deviceId: device.deviceId)
        setupUI()
        loadApps()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let contentView = NSView()
        window?.contentView = contentView
        
        // Search field
        searchField = NSSearchField()
        searchField.placeholderString = "Search apps..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)
        
        // System apps checkbox
        systemAppsCheckbox = NSButton(checkboxWithTitle: "Show system apps", target: self, action: #selector(systemAppsToggled(_:)))
        systemAppsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(systemAppsCheckbox)
        
        // Export button
        exportButton = NSButton(title: "Export APK", target: self, action: #selector(exportSelectedApp))
        exportButton.bezelStyle = .rounded
        exportButton.isEnabled = false
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(exportButton)
        
        // Open in File Manager button
        openInFileManagerButton = NSButton(title: "Open in File Manager", target: self, action: #selector(openInFileManager))
        openInFileManagerButton.bezelStyle = .rounded
        openInFileManagerButton.isEnabled = false
        openInFileManagerButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(openInFileManagerButton)
        
        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressIndicator)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Loading apps...")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Table view in scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Create columns
        let packageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("package"))
        packageColumn.title = "Package Name"
        packageColumn.width = 300
        packageColumn.sortDescriptorPrototype = NSSortDescriptor(key: "packageName", ascending: true)
        tableView.addTableColumn(packageColumn)
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "App Name"
        nameColumn.width = 200
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "appName", ascending: true)
        tableView.addTableColumn(nameColumn)
        
        let versionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        versionColumn.title = "Version"
        versionColumn.width = 100
        tableView.addTableColumn(versionColumn)
        
        // Remove type column for now since we don't load that info upfront
        
        // Remove APK type column for now since we don't load that info upfront
        
        scrollView.documentView = tableView
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Search field
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchField.widthAnchor.constraint(equalToConstant: 300),
            
            // System apps checkbox
            systemAppsCheckbox.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            systemAppsCheckbox.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 20),
            
            // Open in File Manager button
            openInFileManagerButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            openInFileManagerButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            openInFileManagerButton.widthAnchor.constraint(equalToConstant: 150),
            
            // Export button
            exportButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: openInFileManagerButton.leadingAnchor, constant: -10),
            exportButton.widthAnchor.constraint(equalToConstant: 100),
            
            // Progress indicator
            progressIndicator.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -10),
            
            // Table view
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        // Register for selection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tableViewSelectionChanged(_:)),
            name: NSTableView.selectionDidChangeNotification,
            object: tableView
        )
    }
    
    private func loadApps() {
        guard !isLoading else { return }
        
        isLoading = true
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = "Loading apps..."
        exportButton.isEnabled = false
        
        let includeSystemApps = systemAppsCheckbox.state == .on
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let appManager = self.appManager else { return }
            
            let apps = appManager.getInstalledApps(includeSystemApps: includeSystemApps)
            
            DispatchQueue.main.async {
                self.apps = apps
                self.filterApps()
                self.progressIndicator.stopAnimation(nil)
                self.isLoading = false
                self.updateStatusLabel()
            }
        }
    }
    
    private func filterApps() {
        let searchText = searchField.stringValue.lowercased()
        
        if searchText.isEmpty {
            filteredApps = apps
        } else {
            filteredApps = apps.filter { app in
                app.packageName.lowercased().contains(searchText) ||
                app.displayName.lowercased().contains(searchText)
            }
        }
        
        tableView.reloadData()
        updateStatusLabel()
    }
    
    private func updateStatusLabel() {
        let totalApps = apps.count
        let displayedApps = filteredApps.count
        
        if displayedApps == totalApps {
            statusLabel.stringValue = "\(totalApps) apps"
        } else {
            statusLabel.stringValue = "Showing \(displayedApps) of \(totalApps) apps"
        }
    }
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        filterApps()
    }
    
    @objc private func systemAppsToggled(_ sender: NSButton) {
        loadApps()
    }
    
    @objc private func tableViewSelectionChanged(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        exportButton.isEnabled = hasSelection
        openInFileManagerButton.isEnabled = hasSelection
    }
    
    @objc private func tableViewDoubleClicked(_ sender: Any) {
        exportSelectedApp()
    }
    
    @objc private func exportSelectedApp() {
        guard tableView.selectedRow >= 0,
              tableView.selectedRow < filteredApps.count else { return }
        
        let app = filteredApps[tableView.selectedRow]
        
        exportButton.isEnabled = false
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = "Exporting \(app.displayName)..."
        
        appManager?.exportAPKWithProgress(package: app, progressHandler: { [weak self] progress, status in
            DispatchQueue.main.async {
                self?.statusLabel.stringValue = status
            }
        }, completion: { [weak self] success, message in
            DispatchQueue.main.async {
                self?.progressIndicator.stopAnimation(nil)
                self?.exportButton.isEnabled = true
                
                if success {
                    self?.statusLabel.stringValue = "Export completed: \(app.displayName)"
                } else {
                    self?.statusLabel.stringValue = "Export failed: \(message ?? "Unknown error")"
                    
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = message ?? "Failed to export APK"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                
                // Reset status after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.updateStatusLabel()
                }
            }
        })
    }
    
    @objc private func openInFileManager() {
        guard tableView.selectedRow >= 0,
              tableView.selectedRow < filteredApps.count else { return }
        
        let app = filteredApps[tableView.selectedRow]
        let dataPath = "/data/data/\(app.packageName)"
        
        // Close current window
        self.window?.close()
        
        // Open File Manager at the app's data directory
        let fileManagerWindow = FileManagerWindow(device: device, adbClient: ADBClient(), initialPath: dataPath)
        fileManagerWindow.showWindow(nil)
        fileManagerWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSTableViewDataSource
extension AppManagerWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
}

// MARK: - NSTableViewDelegate
extension AppManagerWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredApps.count else { return nil }
        
        let app = filteredApps[row]
        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        let textField: NSTextField
        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTextField {
            textField = cell
        } else {
            textField = NSTextField()
            textField.identifier = cellIdentifier
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.font = .systemFont(ofSize: 12)
        }
        
        switch cellIdentifier.rawValue {
        case "package":
            textField.stringValue = app.packageName
        case "name":
            textField.stringValue = app.displayName
        case "version":
            textField.stringValue = "-"  // Version info not loaded upfront
        default:
            textField.stringValue = ""
        }
        
        return textField
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        let ascending = sortDescriptor.ascending
        
        switch sortDescriptor.key {
        case "packageName":
            filteredApps.sort { ascending ? $0.packageName < $1.packageName : $0.packageName > $1.packageName }
        case "appName":
            filteredApps.sort { ascending ? $0.displayName < $1.displayName : $0.displayName > $1.displayName }
        default:
            break
        }
        
        tableView.reloadData()
    }
}
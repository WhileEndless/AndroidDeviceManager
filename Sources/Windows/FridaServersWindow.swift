import Cocoa

class FridaServersWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    private var tableView: NSTableView!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var deleteButton: NSButton!
    private var uploadButton: NSButton!
    private var refreshButton: NSButton!
    private var statusLabel: NSTextField!
    private var device: Device
    private var fridaManager: FridaServerManager
    private var servers: [FridaServer] = []
    private var isRefreshing = false
    
    init(device: Device) {
        self.device = device
        self.fridaManager = FridaServerManager(device: device)
        super.init(window: nil)
        setupWindow()
        refreshServers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Frida Server Management - \(device.modelName)"
        window.center()
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.wantsLayer = true
        
        // Title Section
        let titleLabel = NSTextField(labelWithString: "Frida Server Management")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: 400, width: 300, height: 25)
        contentView.addSubview(titleLabel)
        
        let infoLabel = NSTextField(labelWithString: "Manage Frida servers on \(device.modelName)")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: 380, width: 400, height: 18)
        contentView.addSubview(infoLabel)
        
        // Status Section
        let statusBox = NSBox(frame: NSRect(x: 20, y: 320, width: 710, height: 50))
        statusBox.title = ""
        statusBox.boxType = .custom
        statusBox.fillColor = NSColor.controlBackgroundColor
        statusBox.cornerRadius = 5
        
        statusLabel = NSTextField(labelWithString: "Checking for installed Frida servers...")
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.frame = NSRect(x: 15, y: 15, width: 680, height: 20)
        statusBox.addSubview(statusLabel)
        
        contentView.addSubview(statusBox)
        
        // Table Section
        let tableLabel = NSTextField(labelWithString: "Installed Servers")
        tableLabel.font = NSFont.boldSystemFont(ofSize: 14)
        tableLabel.frame = NSRect(x: 20, y: 290, width: 200, height: 20)
        contentView.addSubview(tableLabel)
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 100, width: 710, height: 180))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 250
        tableView.addTableColumn(nameColumn)
        
        let pathColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathColumn.title = "Path"
        pathColumn.width = 200
        tableView.addTableColumn(pathColumn)
        
        let archColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("arch"))
        archColumn.title = "Architecture"
        archColumn.width = 100
        tableView.addTableColumn(archColumn)
        
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 80
        tableView.addTableColumn(sizeColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 80
        tableView.addTableColumn(statusColumn)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Action Buttons
        startButton = NSButton(frame: NSRect(x: 20, y: 60, width: 70, height: 28))
        startButton.title = "Start"
        startButton.bezelStyle = NSButton.BezelStyle.rounded
        startButton.target = self
        startButton.action = #selector(startServer)
        startButton.isEnabled = false
        contentView.addSubview(startButton)
        
        stopButton = NSButton(frame: NSRect(x: 100, y: 60, width: 70, height: 28))
        stopButton.title = "Stop"
        stopButton.bezelStyle = NSButton.BezelStyle.rounded
        stopButton.target = self
        stopButton.action = #selector(stopServer)
        stopButton.isEnabled = false
        contentView.addSubview(stopButton)
        
        deleteButton = NSButton(frame: NSRect(x: 180, y: 60, width: 70, height: 28))
        deleteButton.title = "Delete"
        deleteButton.bezelStyle = NSButton.BezelStyle.rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteServer)
        deleteButton.isEnabled = false
        contentView.addSubview(deleteButton)
        
        let stopAllButton = NSButton(frame: NSRect(x: 260, y: 60, width: 80, height: 28))
        stopAllButton.title = "Stop All"
        stopAllButton.bezelStyle = NSButton.BezelStyle.rounded
        stopAllButton.target = self
        stopAllButton.action = #selector(stopAllServers)
        contentView.addSubview(stopAllButton)
        
        uploadButton = NSButton(frame: NSRect(x: 350, y: 60, width: 100, height: 28))
        uploadButton.title = "Upload New..."
        uploadButton.bezelStyle = NSButton.BezelStyle.rounded
        uploadButton.target = self
        uploadButton.action = #selector(uploadNewServer)
        contentView.addSubview(uploadButton)
        
        refreshButton = NSButton(frame: NSRect(x: 460, y: 60, width: 80, height: 28))
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = NSButton.BezelStyle.rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked)
        contentView.addSubview(refreshButton)
        
        // GitHub Button
        let githubButton = NSButton(frame: NSRect(x: 550, y: 60, width: 140, height: 28))
        githubButton.title = "Frida on GitHub"
        githubButton.bezelStyle = .rounded
        githubButton.target = self
        githubButton.action = #selector(openFridaGitHub)
        contentView.addSubview(githubButton)
        
        // Bottom buttons
        let closeButton = NSButton(frame: NSRect(x: 650, y: 20, width: 80, height: 28))
        closeButton.title = "Close"
        closeButton.bezelStyle = NSButton.BezelStyle.rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(closeButton)
        
        // Root warning
        let warningLabel = NSTextField(labelWithString: "⚠️ Root access is required to run Frida server")
        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.textColor = NSColor.systemOrange
        warningLabel.frame = NSRect(x: 20, y: 25, width: 300, height: 18)
        contentView.addSubview(warningLabel)
        
        window?.contentView = contentView
    }
    
    @objc private func startServer() {
        guard let selectedServer = getSelectedServer() else { return }
        
        startButton.isEnabled = false
        statusLabel.stringValue = "Starting Frida server..."
        
        fridaManager.startServer(selectedServer) { [weak self] result in
            switch result {
            case .success:
                self?.statusLabel.stringValue = "✅ Frida server started successfully"
                self?.statusLabel.textColor = NSColor.systemGreen
                self?.refreshServers()
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.showAlert(title: "Start Failed", message: error.localizedDescription)
            }
            
            self?.updateButtonStates()
        }
    }
    
    @objc private func stopServer() {
        guard let selectedServer = getSelectedServer() else { return }
        
        stopButton.isEnabled = false
        statusLabel.stringValue = "Stopping Frida server..."
        
        fridaManager.stopServer(selectedServer) { [weak self] result in
            switch result {
            case .success:
                self?.statusLabel.stringValue = "✅ Frida server stopped"
                self?.statusLabel.textColor = NSColor.labelColor
                self?.refreshServers()
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.showAlert(title: "Stop Failed", message: error.localizedDescription)
            }
            
            self?.updateButtonStates()
        }
    }
    
    @objc private func deleteServer() {
        guard let selectedServer = getSelectedServer() else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Frida Server"
        alert.informativeText = "Are you sure you want to delete \(selectedServer.displayName)?\n\nPath: \(selectedServer.path)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.performDelete(selectedServer)
            }
        }
    }
    
    private func performDelete(_ server: FridaServer) {
        deleteButton.isEnabled = false
        statusLabel.stringValue = "Deleting Frida server..."
        
        fridaManager.deleteServer(server) { [weak self] result in
            switch result {
            case .success:
                self?.statusLabel.stringValue = "✅ Frida server deleted"
                self?.statusLabel.textColor = NSColor.labelColor
                self?.refreshServers()
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.showAlert(title: "Delete Failed", message: error.localizedDescription)
            }
            
            self?.updateButtonStates()
        }
    }
    
    @objc private func uploadNewServer() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select Frida server binary for \(device.modelName)"
        openPanel.prompt = "Upload"
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.performUpload(from: url)
            }
        }
    }
    
    private func performUpload(from url: URL) {
        uploadButton.isEnabled = false
        statusLabel.stringValue = "Uploading Frida server..."
        
        let remotePath = "/data/local/tmp/\(url.lastPathComponent)"
        
        fridaManager.uploadServer(from: url.path, to: remotePath) { [weak self] result in
            switch result {
            case .success:
                self?.statusLabel.stringValue = "✅ Frida server uploaded successfully"
                self?.statusLabel.textColor = NSColor.systemGreen
                self?.refreshServers()
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.showAlert(title: "Upload Failed", message: error.localizedDescription)
            }
            
            self?.uploadButton.isEnabled = true
        }
    }
    
    @objc private func refreshButtonClicked() {
        refreshServers()
    }
    
    @objc private func stopAllServers() {
        let alert = NSAlert()
        alert.messageText = "Stop All Frida Servers"
        alert.informativeText = "Are you sure you want to stop all running Frida servers?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Stop All")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.performStopAll()
            }
        }
    }
    
    private func performStopAll() {
        statusLabel.stringValue = "Stopping all Frida servers..."
        
        fridaManager.stopAllFridaServers { [weak self] result in
            switch result {
            case .success:
                self?.statusLabel.stringValue = "✅ All Frida servers stopped"
                self?.statusLabel.textColor = NSColor.labelColor
                self?.refreshServers()
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.showAlert(title: "Stop All Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func refreshServers() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        refreshButton.isEnabled = false
        statusLabel.stringValue = "Searching for Frida servers..."
        statusLabel.textColor = NSColor.labelColor
        
        fridaManager.findInstalledServers { [weak self] result in
            self?.isRefreshing = false
            self?.refreshButton.isEnabled = true
            
            switch result {
            case .success(let foundServers):
                self?.servers = foundServers
                self?.tableView.reloadData()
                
                if foundServers.isEmpty {
                    self?.statusLabel.stringValue = "No Frida servers found. Upload one to get started."
                    self?.statusLabel.textColor = NSColor.secondaryLabelColor
                } else {
                    let runningCount = foundServers.filter { $0.isRunning }.count
                    self?.statusLabel.stringValue = "Found \(foundServers.count) server(s), \(runningCount) running"
                    self?.statusLabel.textColor = NSColor.labelColor
                }
                
            case .failure(let error):
                self?.statusLabel.stringValue = "❌ Failed to search: \(error.localizedDescription)"
                self?.statusLabel.textColor = NSColor.systemRed
                self?.servers = []
                self?.tableView.reloadData()
            }
            
            self?.updateButtonStates()
        }
    }
    
    private func getSelectedServer() -> FridaServer? {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < servers.count else { return nil }
        return servers[selectedRow]
    }
    
    private func updateButtonStates() {
        guard let selectedServer = getSelectedServer() else {
            startButton.isEnabled = false
            stopButton.isEnabled = false
            deleteButton.isEnabled = false
            return
        }
        
        startButton.isEnabled = !selectedServer.isRunning
        stopButton.isEnabled = selectedServer.isRunning
        deleteButton.isEnabled = !selectedServer.isRunning
    }
    
    @objc private func closeWindow() {
        window?.close()
    }
    
    @objc private func openFridaGitHub() {
        if let url = URL(string: "https://github.com/frida/frida/releases") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return servers.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < servers.count else { return nil }
        
        let server = servers[row]
        let cellIdentifier = tableColumn!.identifier
        
        let cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn!.width, height: 20))
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.frame = NSRect(x: 5, y: 2, width: tableColumn!.width - 10, height: 16)
        textField.lineBreakMode = .byTruncatingTail
        
        switch cellIdentifier.rawValue {
        case "name":
            textField.stringValue = server.displayName
            
        case "path":
            textField.stringValue = server.path
            textField.textColor = NSColor.secondaryLabelColor
            
        case "arch":
            textField.stringValue = server.architecture
            textField.alignment = .center
            
        case "size":
            textField.stringValue = server.sizeString
            textField.alignment = .center
            
        case "status":
            if server.isRunning {
                textField.stringValue = "Running"
                textField.textColor = NSColor.systemGreen
            } else {
                textField.stringValue = "Stopped"
                textField.textColor = NSColor.secondaryLabelColor
            }
            textField.alignment = .center
            
        default:
            break
        }
        
        cellView.addSubview(textField)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }
}
import Cocoa

class PortForwardingWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    private var tableView: NSTableView!
    private var localPortField: NSTextField!
    private var remotePortField: NSTextField!
    private var descriptionField: NSTextField!
    private var addButton: NSButton!
    private var deleteButton: NSButton!
    private var typeSelector: NSSegmentedControl!
    private var device: Device
    private var portForwardManager: PortForwardManager
    private var forwards: [PortForward] = []
    
    init(device: Device) {
        self.device = device
        self.portForwardManager = PortForwardManager(device: device)
        super.init(window: nil)
        setupWindow()
        refreshForwards()
        setupDefaultReverse()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Port Forwarding - \(device.modelName)"
        window.center()
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.wantsLayer = true
        
        // Title Section
        let titleLabel = NSTextField(labelWithString: "Port Forwarding Configuration")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: 450, width: 300, height: 25)
        contentView.addSubview(titleLabel)
        
        let deviceLabel = NSTextField(labelWithString: "Device: \(device.modelName)")
        deviceLabel.font = NSFont.systemFont(ofSize: 12)
        deviceLabel.textColor = NSColor.secondaryLabelColor
        deviceLabel.frame = NSRect(x: 20, y: 430, width: 300, height: 18)
        contentView.addSubview(deviceLabel)
        
        // Add Port Section
        let addSectionBox = NSBox(frame: NSRect(x: 20, y: 280, width: 660, height: 140))
        addSectionBox.title = "Add New Port Forwarding"
        
        // Type selector
        typeSelector = NSSegmentedControl(labels: ["Forward (Local → Device)", "Reverse (Device → Local)"], trackingMode: .selectOne, target: self, action: #selector(typeChanged))
        typeSelector.frame = NSRect(x: 15, y: 80, width: 350, height: 28)
        typeSelector.selectedSegment = 1
        addSectionBox.addSubview(typeSelector)
        
        // Port fields row
        let localPortLabel = NSTextField(labelWithString: "Local Port:")
        localPortLabel.frame = NSRect(x: 15, y: 45, width: 80, height: 20)
        addSectionBox.addSubview(localPortLabel)
        
        localPortField = NSTextField(frame: NSRect(x: 100, y: 43, width: 100, height: 24))
        localPortField.placeholderString = "8080"
        addSectionBox.addSubview(localPortField)
        
        let remotePortLabel = NSTextField(labelWithString: "Device Port:")
        remotePortLabel.frame = NSRect(x: 220, y: 45, width: 85, height: 20)
        addSectionBox.addSubview(remotePortLabel)
        
        remotePortField = NSTextField(frame: NSRect(x: 310, y: 43, width: 100, height: 24))
        remotePortField.placeholderString = "8080"
        addSectionBox.addSubview(remotePortField)
        
        let descriptionLabel = NSTextField(labelWithString: "Description:")
        descriptionLabel.frame = NSRect(x: 430, y: 45, width: 80, height: 20)
        addSectionBox.addSubview(descriptionLabel)
        
        descriptionField = NSTextField(frame: NSRect(x: 515, y: 43, width: 130, height: 24))
        descriptionField.placeholderString = "Optional"
        addSectionBox.addSubview(descriptionField)
        
        // Add button
        addButton = NSButton(frame: NSRect(x: 570, y: 5, width: 75, height: 28))
        addButton.title = "Add"
        addButton.bezelStyle = NSButton.BezelStyle.rounded
        addButton.target = self
        addButton.action = #selector(addForward)
        addButton.keyEquivalent = "\r"
        addSectionBox.addSubview(addButton)
        
        // Info label
        let infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.tertiaryLabelColor
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = .clear
        infoLabel.frame = NSRect(x: 15, y: 10, width: 550, height: 20)
        infoLabel.tag = 999
        addSectionBox.addSubview(infoLabel)
        
        contentView.addSubview(addSectionBox)
        
        // Active Forwards Section
        let forwardsSectionLabel = NSTextField(labelWithString: "Active Port Forwards")
        forwardsSectionLabel.font = NSFont.boldSystemFont(ofSize: 14)
        forwardsSectionLabel.frame = NSRect(x: 20, y: 250, width: 200, height: 20)
        contentView.addSubview(forwardsSectionLabel)
        
        // Table view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 660, height: 180))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 100
        tableView.addTableColumn(typeColumn)
        
        let localPortColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("localPort"))
        localPortColumn.title = "Local Port"
        localPortColumn.width = 100
        tableView.addTableColumn(localPortColumn)
        
        let remotePortColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("remotePort"))
        remotePortColumn.title = "Device Port"
        remotePortColumn.width = 100
        tableView.addTableColumn(remotePortColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 330
        tableView.addTableColumn(descriptionColumn)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Bottom buttons
        deleteButton = NSButton(frame: NSRect(x: 20, y: 20, width: 100, height: 28))
        deleteButton.title = "Delete Selected"
        deleteButton.bezelStyle = NSButton.BezelStyle.rounded
        deleteButton.target = self
        deleteButton.action = #selector(removeForward)
        deleteButton.isEnabled = false
        contentView.addSubview(deleteButton)
        
        let refreshButton = NSButton(frame: NSRect(x: 130, y: 20, width: 80, height: 28))
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = NSButton.BezelStyle.rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked)
        contentView.addSubview(refreshButton)
        
        let closeButton = NSButton(frame: NSRect(x: 600, y: 20, width: 80, height: 28))
        closeButton.title = "Close"
        closeButton.bezelStyle = NSButton.BezelStyle.rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.keyEquivalent = "\u{1b}" // ESC key
        contentView.addSubview(closeButton)
        
        // Hints section
        window?.contentView = contentView
        updateInfoLabel()
    }
    
    @objc private func addForward() {
        guard let localPort = Int(localPortField.stringValue),
              let remotePort = Int(remotePortField.stringValue) else {
            showAlert(title: "Invalid Input", message: "Please enter valid port numbers (1-65535).")
            return
        }
        
        let description = descriptionField.stringValue
        let type: ForwardType = typeSelector.selectedSegment == 0 ? .forward : .reverse
        
        let result = portForwardManager.createForward(localPort: localPort, remotePort: remotePort, type: type, description: description)
        
        switch result {
        case .success:
            localPortField.stringValue = ""
            remotePortField.stringValue = ""
            descriptionField.stringValue = ""
            refreshForwards()
            
        case .failure(let error):
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    @objc private func removeForward() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < forwards.count else { return }
        
        let forward = forwards[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Delete Port Forward"
        alert.informativeText = "Are you sure you want to delete this port forward?\n\n\(forward.type.rawValue): \(forward.localPort) ↔ \(forward.remotePort)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            if response == .alertFirstButtonReturn {
                let result = self?.portForwardManager.removeForward(forward)
                
                switch result {
                case .success:
                    self?.refreshForwards()
                    
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                    
                case .none:
                    break
                }
            }
        }
    }
    
    @objc private func typeChanged() {
        updateInfoLabel()
    }
    
    @objc private func refreshButtonClicked() {
        refreshForwards()
    }
    
    private func refreshForwards() {
        portForwardManager.refreshActiveForwards()
        forwards = portForwardManager.getActiveForwards()
        tableView.reloadData()
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        deleteButton.isEnabled = tableView.selectedRow >= 0
    }
    
    private func updateInfoLabel() {
        if let infoLabel = window?.contentView?.viewWithTag(999) as? NSTextField {
            if typeSelector?.selectedSegment == 0 {
                infoLabel.stringValue = "ℹ️ Forward: Makes your local port accessible on the device (e.g., local server → device browser)"
            } else {
                infoLabel.stringValue = "ℹ️ Reverse: Makes device port accessible locally (e.g., device app → local development server)"
            }
        }
    }
    
    @objc private func closeWindow() {
        window?.close()
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
        return forwards.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < forwards.count else { return nil }
        
        let forward = forwards[row]
        let cellIdentifier = tableColumn!.identifier
        
        let cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn!.width, height: 20))
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.frame = NSRect(x: 5, y: 2, width: tableColumn!.width - 10, height: 16)
        textField.lineBreakMode = .byTruncatingTail
        
        switch cellIdentifier.rawValue {
        case "type":
            textField.stringValue = forward.type.rawValue
            textField.textColor = forward.type == .forward ? NSColor.systemBlue : NSColor.systemPurple
            
        case "localPort":
            textField.stringValue = "\(forward.localPort)"
            textField.alignment = .center
            
        case "remotePort":
            textField.stringValue = "\(forward.remotePort)"
            textField.alignment = .center
            
        case "description":
            textField.stringValue = forward.description.isEmpty ? "-" : forward.description
            textField.textColor = forward.description.isEmpty ? NSColor.tertiaryLabelColor : NSColor.labelColor
            
        default:
            break
        }
        
        cellView.addSubview(textField)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }
    
    private func setupDefaultReverse() {
        // Check if reverse 8080:8080 already exists
        let existingReverse = forwards.first { forward in
            forward.type == .reverse && 
            forward.localPort == 8080 && 
            forward.remotePort == 8080
        }
        
        // If not exists, create it
        if existingReverse == nil {
            _ = portForwardManager.createForward(
                localPort: 8080, 
                remotePort: 8080, 
                type: .reverse, 
                description: "Default local server access"
            )
            refreshForwards()
        }
    }
}
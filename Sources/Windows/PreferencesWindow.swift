import Cocoa

class PreferencesWindow: NSWindowController {
    private var screenshotPathField: NSTextField!
    private var adbPathField: NSTextField!
    private var autoConnectCheckbox: NSButton!
    
    override init(window: NSWindow?) {
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Preferences"
        newWindow.center()
        self.window = newWindow
        
        setupContent()
        loadPreferences()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.wantsLayer = true
        
        var yPosition = contentView.bounds.height - 50
        
        // Title
        let titleLabel = createLabel(text: "Android Device Manager Preferences", fontSize: 16, bold: true)
        titleLabel.frame = NSRect(x: 20, y: yPosition, width: 460, height: 25)
        contentView.addSubview(titleLabel)
        
        yPosition -= 50
        
        // Screenshot Directory Section
        let screenshotSectionLabel = createLabel(text: "Screenshot Settings", fontSize: 14, bold: true)
        screenshotSectionLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(screenshotSectionLabel)
        
        yPosition -= 30
        
        let screenshotPathLabel = createLabel(text: "Screenshot Directory:")
        screenshotPathLabel.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        contentView.addSubview(screenshotPathLabel)
        
        screenshotPathField = NSTextField(frame: NSRect(x: 200, y: yPosition, width: 200, height: 22))
        screenshotPathField.placeholderString = "~/Pictures/AndroidScreenshots"
        contentView.addSubview(screenshotPathField)
        
        let browseButton = NSButton(frame: NSRect(x: 410, y: yPosition, width: 70, height: 22))
        browseButton.title = "Browse..."
        browseButton.bezelStyle = NSButton.BezelStyle.rounded
        browseButton.target = self
        browseButton.action = #selector(browseForDirectory)
        contentView.addSubview(browseButton)
        
        yPosition -= 50
        
        // ADB Settings Section
        let adbSectionLabel = createLabel(text: "ADB Settings", fontSize: 14, bold: true)
        adbSectionLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        contentView.addSubview(adbSectionLabel)
        
        yPosition -= 30
        
        let adbPathLabel = createLabel(text: "ADB Path:")
        adbPathLabel.frame = NSRect(x: 40, y: yPosition, width: 150, height: 20)
        contentView.addSubview(adbPathLabel)
        
        adbPathField = NSTextField(frame: NSRect(x: 200, y: yPosition, width: 200, height: 22))
        adbPathField.placeholderString = "/usr/local/bin/adb"
        contentView.addSubview(adbPathField)
        
        let adbBrowseButton = NSButton(frame: NSRect(x: 410, y: yPosition, width: 70, height: 22))
        adbBrowseButton.title = "Browse..."
        adbBrowseButton.bezelStyle = NSButton.BezelStyle.rounded
        adbBrowseButton.target = self
        adbBrowseButton.action = #selector(browseForADB)
        contentView.addSubview(adbBrowseButton)
        
        yPosition -= 30
        
        autoConnectCheckbox = NSButton(checkboxWithTitle: "Auto-connect to devices on startup", target: nil, action: nil)
        autoConnectCheckbox.frame = NSRect(x: 40, y: yPosition, width: 300, height: 20)
        contentView.addSubview(autoConnectCheckbox)
        
        // Bottom buttons
        let cancelButton = NSButton(frame: NSRect(x: 290, y: 20, width: 90, height: 30))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = NSButton.BezelStyle.rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        let saveButton = NSButton(frame: NSRect(x: 390, y: 20, width: 90, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = NSButton.BezelStyle.rounded
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
        
        let resetButton = NSButton(frame: NSRect(x: 20, y: 20, width: 120, height: 30))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = NSButton.BezelStyle.rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        contentView.addSubview(resetButton)
        
        window?.contentView = contentView
    }
    
    private func createLabel(text: String, fontSize: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }
    
    private func loadPreferences() {
        let prefs = Preferences.shared
        screenshotPathField.stringValue = prefs.screenshotDirectory
        adbPathField.stringValue = prefs.adbPath
        autoConnectCheckbox.state = prefs.autoConnect ? .on : .off
    }
    
    @objc private func browseForDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Select"
        openPanel.message = "Select directory for screenshots"
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.screenshotPathField.stringValue = url.path
            }
        }
    }
    
    @objc private func browseForADB() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = [""]
        openPanel.prompt = "Select"
        openPanel.message = "Select ADB executable"
        openPanel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.adbPathField.stringValue = url.path
            }
        }
    }
    
    @objc private func saveClicked() {
        let prefs = Preferences.shared
        
        // Validate and create screenshot directory if needed
        let screenshotPath = screenshotPathField.stringValue
        if !screenshotPath.isEmpty {
            let expandedPath = NSString(string: screenshotPath).expandingTildeInPath
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: expandedPath) {
                do {
                    try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    showAlert(title: "Error", message: "Could not create screenshot directory: \(error.localizedDescription)")
                    return
                }
            }
            prefs.screenshotDirectory = expandedPath
        }
        
        // Validate ADB path
        let adbPath = adbPathField.stringValue
        if !adbPath.isEmpty {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: adbPath) {
                showAlert(title: "Error", message: "ADB executable not found at specified path")
                return
            }
            prefs.adbPath = adbPath
        }
        
        // Save other preferences
        prefs.autoConnect = autoConnectCheckbox.state == .on
        
        window?.close()
    }
    
    @objc private func cancelClicked() {
        window?.close()
    }
    
    @objc private func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = "Are you sure you want to reset all preferences to their default values?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            if response == .alertFirstButtonReturn {
                Preferences.shared.resetToDefaults()
                self?.loadPreferences()
            }
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
}
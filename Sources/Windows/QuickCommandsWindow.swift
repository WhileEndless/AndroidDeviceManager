import Cocoa

class QuickCommandsWindow: NSWindowController {
    private var commandField: NSTextField!
    private var outputTextView: NSTextView!
    private var runButton: NSButton!
    private var device: Device
    private var historyPopUp: NSPopUpButton!
    
    private let commandHistory = [
        "Clear Selection": "",
        "Package List": "pm list packages",
        "Running Apps": "ps",
        "Memory Info": "cat /proc/meminfo | head -10",
        "Storage Info": "df -h",
        "Battery Info": "dumpsys battery",
        "Wi-Fi Info": "dumpsys wifi | grep \"mWifiInfo\"",
        "Screen Info": "wm size && wm density",
        "CPU Info": "cat /proc/cpuinfo | head -20",
        "Reboot": "reboot",
        "Reboot to Recovery": "reboot recovery",
        "Reboot to Bootloader": "reboot bootloader"
    ]
    
    init(device: Device) {
        self.device = device
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Quick Commands - \(device.modelName)"
        window.center()
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.wantsLayer = true
        
        // History popup
        historyPopUp = NSPopUpButton(frame: NSRect(x: 20, y: 340, width: 200, height: 26))
        historyPopUp.target = self
        historyPopUp.action = #selector(historySelected)
        
        for (title, _) in commandHistory {
            historyPopUp.addItem(withTitle: title)
        }
        contentView.addSubview(historyPopUp)
        
        // Command field
        let commandLabel = NSTextField(labelWithString: "Command:")
        commandLabel.frame = NSRect(x: 20, y: 310, width: 80, height: 20)
        contentView.addSubview(commandLabel)
        
        commandField = NSTextField(frame: NSRect(x: 100, y: 308, width: 380, height: 24))
        commandField.placeholderString = "Enter ADB shell command"
        contentView.addSubview(commandField)
        
        // Run button
        runButton = NSButton(frame: NSRect(x: 490, y: 308, width: 90, height: 24))
        runButton.title = "Run"
        runButton.bezelStyle = NSButton.BezelStyle.rounded
        runButton.target = self
        runButton.action = #selector(runCommand)
        runButton.keyEquivalent = "\r"
        contentView.addSubview(runButton)
        
        // Output text view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 50, width: 560, height: 250))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder
        
        outputTextView = NSTextView(frame: scrollView.bounds)
        outputTextView.isEditable = false
        outputTextView.isRichText = false
        outputTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        outputTextView.autoresizingMask = [.width, .height]
        outputTextView.string = "Output will appear here...\n"
        outputTextView.textColor = NSColor.labelColor
        outputTextView.backgroundColor = NSColor.textBackgroundColor
        
        scrollView.documentView = outputTextView
        contentView.addSubview(scrollView)
        
        // Clear button
        let clearButton = NSButton(frame: NSRect(x: 20, y: 20, width: 80, height: 24))
        clearButton.title = "Clear"
        clearButton.bezelStyle = NSButton.BezelStyle.rounded
        clearButton.target = self
        clearButton.action = #selector(clearOutput)
        contentView.addSubview(clearButton)
        
        // Close button
        let closeButton = NSButton(frame: NSRect(x: 500, y: 20, width: 80, height: 24))
        closeButton.title = "Close"
        closeButton.bezelStyle = NSButton.BezelStyle.rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        contentView.addSubview(closeButton)
        
        window?.contentView = contentView
    }
    
    @objc private func historySelected() {
        let selectedIndex = historyPopUp.indexOfSelectedItem
        if selectedIndex > 0 && selectedIndex < commandHistory.count {
            let (_, command) = Array(commandHistory)[selectedIndex]
            commandField.stringValue = command
        } else {
            commandField.stringValue = ""
        }
    }
    
    @objc private func runCommand() {
        let command = commandField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !command.isEmpty else {
            appendOutput("Please enter a command.\n", isError: true)
            return
        }
        
        // Tehlikeli komutlar için onay
        let dangerousCommands = ["reboot", "rm -rf", "factory reset", "wipe"]
        let needsConfirmation = dangerousCommands.contains { command.lowercased().contains($0) }
        
        if needsConfirmation {
            let alert = NSAlert()
            alert.messageText = "Confirm Command"
            alert.informativeText = "This command may have significant effects:\n\n\(command)\n\nAre you sure you want to run it?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Run")
            alert.addButton(withTitle: "Cancel")
            
            alert.beginSheetModal(for: window!) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.executeCommand(command)
                }
            }
        } else {
            executeCommand(command)
        }
    }
    
    private func executeCommand(_ command: String) {
        runButton.isEnabled = false
        appendOutput("\n$ \(command)\n", isError: false)
        
        let shellManager = ShellManager(device: device)
        shellManager.runQuickCommand(command) { [weak self] result in
            self?.runButton.isEnabled = true
            
            if result.isSuccess {
                self?.appendOutput(result.output, isError: false)
            } else {
                self?.appendOutput("Error: \(result.error)\n", isError: true)
            }
            
            if !result.output.hasSuffix("\n") {
                self?.appendOutput("\n", isError: false)
            }
        }
    }
    
    private func appendOutput(_ text: String, isError: Bool) {
        let attributedString = NSMutableAttributedString(string: text)
        
        if isError {
            attributedString.addAttribute(.foregroundColor, 
                                        value: NSColor.systemRed, 
                                        range: NSRange(location: 0, length: text.count))
        } else {
            attributedString.addAttribute(.foregroundColor,
                                        value: NSColor.labelColor,
                                        range: NSRange(location: 0, length: text.count))
        }
        
        outputTextView.textStorage?.append(attributedString)
        outputTextView.scrollToEndOfDocument(nil)
    }
    
    @objc private func clearOutput() {
        outputTextView.string = "Output will appear here...\n"
    }
    
    @objc private func closeWindow() {
        window?.close()
    }
}
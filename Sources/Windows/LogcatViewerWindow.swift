import Cocoa

// Custom content view that handles keyboard shortcuts
class LogcatContentView: NSView {
    weak var textView: NSTextView?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Cmd+A
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            textView?.selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

class LogcatViewerWindow: NSWindowController, NSWindowDelegate, LogcatManagerDelegate {
    // UI Elements
    private var packageField: NSTextField!
    private var searchField: NSSearchField!
    private var pidLabel: NSTextField!
    private var maxLogsField: NSTextField!
    private var autoScrollCheckbox: NSButton!
    private var levelButtons: [LogLevel: NSButton] = [:]
    private var clearButton: NSButton!
    private var pauseButton: NSButton!
    private var exportButton: NSButton!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var statusLabel: NSTextField!
    private var topControlsView: NSView!
    
    // Data
    private let device: Device
    private let logcatManager: LogcatManager
    private var logEntries: [LogEntry] = []
    private var isPaused = false
    private var autoScroll = true
    private var maxLogEntries = 10000
    
    // Performance
    private var pendingEntries: [LogEntry] = []
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 0.1
    private var isUpdating = false
    private let maxVisibleLines = 2000
    
    init(device: Device) {
        self.device = device
        self.logcatManager = LogcatManager(device: device)
        super.init(window: nil)
        setupWindow()
        logcatManager.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Enable fullscreen
        window.collectionBehavior = [.fullScreenPrimary]
        
        window.title = "Logcat Viewer - \(device.modelName)"
        window.center()
        window.minSize = NSSize(width: 800, height: 500)
        window.delegate = self
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = LogcatContentView(frame: window!.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        // Top controls container - fixed at top
        topControlsView = NSView(frame: NSRect(x: 0, y: contentView.bounds.height - 150, 
                                              width: contentView.bounds.width, height: 150))
        topControlsView.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(topControlsView)
        
        setupTopControls()
        
        // Log View - fills remaining space
        setupLogView(in: contentView)
        
        // Status Bar - fixed at bottom
        setupStatusBar(in: contentView)
        
        window?.contentView = contentView
        
        // Configure and start
        logcatManager.setMaxLogCount(maxLogEntries)
        logcatManager.startLogcat()
        statusLabel.stringValue = "Showing all logs (max: \(maxLogEntries))"
        
        // Start update timer with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: self?.updateInterval ?? 0.1, repeats: true) { _ in
                self?.processPendingEntries()
            }
        }
    }
    
    private func setupTopControls() {
        // First row - Package filter (y: 100 from top, which is 50 from bottom of container)
        let row1Y: CGFloat = 100
        
        let packageLabel = NSTextField(labelWithString: "Package:")
        packageLabel.frame = NSRect(x: 20, y: row1Y + 3, width: 60, height: 20)
        topControlsView.addSubview(packageLabel)
        
        packageField = NSTextField(frame: NSRect(x: 85, y: row1Y, width: 300, height: 24))
        packageField.placeholderString = "com.example.app (optional)"
        packageField.target = self
        packageField.action = #selector(applyPackageFilter)
        packageField.bezelStyle = .roundedBezel
        topControlsView.addSubview(packageField)
        
        let applyButton = NSButton(frame: NSRect(x: 390, y: row1Y - 2, width: 80, height: 28))
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applyPackageFilter)
        topControlsView.addSubview(applyButton)
        
        pidLabel = NSTextField(labelWithString: "PID: -")
        pidLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        pidLabel.textColor = NSColor.secondaryLabelColor
        pidLabel.isEditable = false
        pidLabel.isBordered = false
        pidLabel.backgroundColor = .clear
        pidLabel.frame = NSRect(x: 480, y: row1Y + 3, width: 100, height: 20)
        topControlsView.addSubview(pidLabel)
        
        searchField = NSSearchField(frame: NSRect(x: topControlsView.bounds.width - 270, y: row1Y, width: 250, height: 24))
        searchField.placeholderString = "Search logs..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.autoresizingMask = [.minXMargin]
        topControlsView.addSubview(searchField)
        
        // Second row - Log levels (y: 50 from top, which is 100 from bottom of container)
        let row2Y: CGFloat = 50
        
        let levelsLabel = NSTextField(labelWithString: "Levels:")
        levelsLabel.frame = NSRect(x: 20, y: row2Y + 3, width: 50, height: 20)
        topControlsView.addSubview(levelsLabel)
        
        var x: CGFloat = 80
        for level in LogLevel.allCases {
            let button = NSButton(checkboxWithTitle: level.rawValue, target: self, action: #selector(levelFilterChanged(_:)))
            button.frame = NSRect(x: x, y: row2Y, width: 50, height: 24)
            button.state = .on
            button.tag = LogLevel.allCases.firstIndex(of: level)!
            
            if let cell = button.cell as? NSButtonCell {
                let attributed = NSMutableAttributedString(string: level.rawValue)
                attributed.addAttribute(.foregroundColor, value: level.color, range: NSRange(location: 0, length: 1))
                attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: 12, weight: .semibold), range: NSRange(location: 0, length: 1))
                cell.attributedTitle = attributed
            }
            
            topControlsView.addSubview(button)
            levelButtons[level] = button
            x += 55
        }
        
        clearButton = NSButton(frame: NSRect(x: x + 30, y: row2Y - 2, width: 70, height: 28))
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearLogs)
        topControlsView.addSubview(clearButton)
        
        pauseButton = NSButton(frame: NSRect(x: x + 105, y: row2Y - 2, width: 70, height: 28))
        pauseButton.title = "Pause"
        pauseButton.bezelStyle = .rounded
        pauseButton.target = self
        pauseButton.action = #selector(togglePause)
        topControlsView.addSubview(pauseButton)
        
        exportButton = NSButton(frame: NSRect(x: x + 180, y: row2Y - 2, width: 70, height: 28))
        exportButton.title = "Export"
        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportLogs)
        topControlsView.addSubview(exportButton)
        
        // Settings (right side)
        let settingsX = topControlsView.bounds.width - 270
        
        let maxLogsLabel = NSTextField(labelWithString: "Max logs:")
        maxLogsLabel.frame = NSRect(x: settingsX, y: row2Y + 3, width: 65, height: 20)
        maxLogsLabel.autoresizingMask = [.minXMargin]
        topControlsView.addSubview(maxLogsLabel)
        
        maxLogsField = NSTextField(frame: NSRect(x: settingsX + 70, y: row2Y, width: 80, height: 24))
        maxLogsField.stringValue = "\(maxLogEntries)"
        maxLogsField.placeholderString = "10000"
        maxLogsField.target = self
        maxLogsField.action = #selector(maxLogsChanged)
        maxLogsField.bezelStyle = .roundedBezel
        maxLogsField.autoresizingMask = [.minXMargin]
        topControlsView.addSubview(maxLogsField)
        
        autoScrollCheckbox = NSButton(checkboxWithTitle: "Auto-scroll", target: self, action: #selector(autoScrollChanged))
        autoScrollCheckbox.frame = NSRect(x: settingsX + 160, y: row2Y, width: 100, height: 24)
        autoScrollCheckbox.state = autoScroll ? .on : .off
        autoScrollCheckbox.autoresizingMask = [.minXMargin]
        topControlsView.addSubview(autoScrollCheckbox)
    }
    
    private func setupLogView(in contentView: NSView) {
        let topOffset: CGFloat = 150
        let bottomOffset: CGFloat = 30
        
        scrollView = NSScrollView(frame: NSRect(
            x: 20,
            y: bottomOffset,
            width: contentView.bounds.width - 40,
            height: contentView.bounds.height - topOffset - bottomOffset
        ))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        textView = NSTextView(frame: scrollView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = false
        textView.isRichText = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.allowsUndo = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Enable text selection and copying
        textView.isSelectable = true
        textView.allowsDocumentBackgroundColorChange = false
        
        // Performance optimizations
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        
        // Connect the textView to the content view for keyboard shortcuts
        if let logcatContentView = contentView as? LogcatContentView {
            logcatContentView.textView = textView
        }
    }
    
    private func setupStatusBar(in contentView: NSView) {
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.frame = NSRect(x: 20, y: 5, width: contentView.bounds.width - 40, height: 20)
        statusLabel.autoresizingMask = [.width]
        contentView.addSubview(statusLabel)
    }
    
    // MARK: - Actions
    
    @objc private func applyPackageFilter() {
        let package = packageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        clearLogsDisplay()
        logcatManager.stopLogcat()
        
        if package.isEmpty {
            statusLabel.stringValue = "Showing all logs (max: \(maxLogEntries))"
            logcatManager.startLogcat()
        } else {
            statusLabel.stringValue = "Filtering logs for: \(package) (max: \(maxLogEntries))"
            logcatManager.startLogcat(packageName: package)
        }
    }
    
    @objc private func searchFieldChanged() {
        let searchText = searchField.stringValue
        logcatManager.setSearchFilter(searchText)
        
        if !searchText.isEmpty {
            statusLabel.stringValue = "Searching for: \(searchText)"
        }
    }
    
    @objc private func levelFilterChanged(_ sender: NSButton) {
        var enabledLevels = Set<LogLevel>()
        
        for (level, button) in levelButtons {
            if button.state == .on {
                enabledLevels.insert(level)
            }
        }
        
        logcatManager.setLevelFilter(enabledLevels)
    }
    
    @objc private func clearLogs() {
        clearLogsDisplay()
        logcatManager.clearLogs()
        statusLabel.stringValue = "Logs cleared"
    }
    
    private func clearLogsDisplay() {
        logEntries.removeAll()
        pendingEntries.removeAll()
        textView.string = ""
    }
    
    @objc private func togglePause() {
        isPaused.toggle()
        pauseButton.title = isPaused ? "Resume" : "Pause"
        statusLabel.stringValue = isPaused ? "Paused" : "Resumed"
    }
    
    @objc private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["txt", "log"]
        savePanel.nameFieldStringValue = "logcat_\(Date().timeIntervalSince1970).log"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = savePanel.url, let self = self {
                do {
                    try self.logcatManager.exportLogs(to: url, entries: self.logEntries)
                    self.statusLabel.stringValue = "Exported \(self.logEntries.count) log entries"
                } catch {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func autoScrollChanged() {
        autoScroll = autoScrollCheckbox.state == .on
    }
    
    @objc private func maxLogsChanged() {
        let value = maxLogsField.integerValue
        if value > 0 {
            maxLogEntries = max(100, min(value, 50000))
            maxLogsField.stringValue = "\(maxLogEntries)"
            
            logcatManager.setMaxLogCount(maxLogEntries)
            
            if logEntries.count > maxLogEntries {
                logEntries = Array(logEntries.suffix(maxLogEntries))
                rebuildLogDisplay()
            }
            
            statusLabel.stringValue = "Max log limit set to \(maxLogEntries)"
        } else {
            maxLogsField.stringValue = "\(maxLogEntries)"
        }
    }
    
    // MARK: - LogcatManagerDelegate
    
    func logcatManager(_ manager: LogcatManager, didReceiveEntry entry: LogEntry) {
        guard !isPaused else { return }
        pendingEntries.append(entry)
    }
    
    func logcatManager(_ manager: LogcatManager, didUpdatePID oldPID: String?, newPID: String?) {
        if let pid = newPID {
            pidLabel.stringValue = "PID: \(pid)"
            pidLabel.textColor = NSColor.systemGreen
        } else {
            pidLabel.stringValue = "PID: -"
            pidLabel.textColor = NSColor.systemRed
        }
        
        if let package = packageField.stringValue.isEmpty ? nil : packageField.stringValue {
            if newPID != nil {
                statusLabel.stringValue = "Filtering logs for \(package) (PID: \(newPID!))"
            } else {
                statusLabel.stringValue = "No process found for \(package)"
            }
        }
    }
    
    func logcatManager(_ manager: LogcatManager, didEncounterError error: Error) {
        statusLabel.stringValue = "Error: \(error.localizedDescription)"
        statusLabel.textColor = NSColor.systemRed
    }
    
    // MARK: - Private Methods
    
    private func processPendingEntries() {
        guard !pendingEntries.isEmpty && !isUpdating else { return }
        
        isUpdating = true
        
        let entriesToProcess = pendingEntries.prefix(200)
        pendingEntries.removeFirst(min(200, pendingEntries.count))
        
        logEntries.append(contentsOf: entriesToProcess)
        
        if logEntries.count > maxLogEntries {
            let toRemove = logEntries.count - maxLogEntries
            logEntries.removeFirst(toRemove)
        }
        
        updateLogDisplay()
        
        statusLabel.stringValue = "Logs: \(logEntries.count) / \(maxLogEntries)"
        
        isUpdating = false
    }
    
    private func updateLogDisplay() {
        let visibleEntries = logEntries.suffix(maxVisibleLines)
        
        let currentLineCount = textView.string.components(separatedBy: "\n").count - 1
        
        if currentLineCount > Int(Double(maxVisibleLines) * 1.5) {
            rebuildLogDisplay()
        } else {
            textView.textStorage?.beginEditing()
            
            let newEntries = max(0, visibleEntries.count - currentLineCount)
            if newEntries > 0 {
                let entriesToAdd = visibleEntries.suffix(newEntries)
                for entry in entriesToAdd {
                    appendLogEntry(entry)
                }
            }
            
            textView.textStorage?.endEditing()
            
            if autoScroll {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
    
    private func appendLogEntry(_ entry: LogEntry) {
        textView.textStorage?.append(entry.formattedLine)
        textView.textStorage?.append(NSAttributedString(string: "\n"))
    }
    
    private func rebuildLogDisplay() {
        autoreleasepool {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            textView.textStorage?.beginEditing()
            
            textView.string = ""
            
            let entriesToShow = logEntries.suffix(maxVisibleLines)
            for entry in entriesToShow {
                appendLogEntry(entry)
            }
            
            textView.textStorage?.endEditing()
            
            if autoScroll {
                textView.scrollToEndOfDocument(nil)
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
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        logcatManager.stopLogcat()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Make text view first responder
        window?.makeFirstResponder(textView)
    }
}
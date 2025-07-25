import Cocoa

class FileUploadProgressWindow: NSWindowController {
    private var progressBar: NSProgressIndicator!
    private var fileNameLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var speedLabel: NSTextField!
    private var timeRemainingLabel: NSTextField!
    private var cancelButton: NSButton!
    
    private var isCancelled = false
    var onCancel: (() -> Void)?
    
    override init(window: NSWindow?) {
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Uploading Files"
        window.center()
        self.window = window
        
        setupContent()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.wantsLayer = true
        
        // File name label
        fileNameLabel = NSTextField(labelWithString: "Preparing...")
        fileNameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        fileNameLabel.alignment = .center
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileNameLabel)
        
        // Progress bar
        progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressBar)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "0 / 0 MB")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Speed label
        speedLabel = NSTextField(labelWithString: "0 MB/s")
        speedLabel.font = NSFont.systemFont(ofSize: 12)
        speedLabel.alignment = .right
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(speedLabel)
        
        // Time remaining label
        timeRemainingLabel = NSTextField(labelWithString: "Calculating...")
        timeRemainingLabel.font = NSFont.systemFont(ofSize: 12)
        timeRemainingLabel.alignment = .center
        timeRemainingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeRemainingLabel)
        
        // Cancel button
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // File name
            fileNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            fileNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Progress bar
            progressBar.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 20),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressBar.heightAnchor.constraint(equalToConstant: 20),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            // Speed label
            speedLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            speedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Time remaining
            timeRemainingLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            timeRemainingLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Cancel button
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        window?.contentView = contentView
    }
    
    // MARK: - Public Methods
    
    func updateFileName(_ name: String) {
        DispatchQueue.main.async {
            self.fileNameLabel.stringValue = name
        }
    }
    
    func updateProgress(_ progress: Double, bytesTransferred: Int64, totalBytes: Int64, speed: Double) {
        DispatchQueue.main.async {
            self.progressBar.doubleValue = progress
            
            // Update status
            let transferred = self.formatBytes(bytesTransferred)
            let total = self.formatBytes(totalBytes)
            self.statusLabel.stringValue = "\(transferred) / \(total)"
            
            // Update speed
            self.speedLabel.stringValue = "\(self.formatBytes(Int64(speed)))/s"
            
            // Calculate time remaining
            if speed > 0 {
                let remainingBytes = totalBytes - bytesTransferred
                let remainingSeconds = Double(remainingBytes) / speed
                self.timeRemainingLabel.stringValue = self.formatTimeRemaining(remainingSeconds)
            }
        }
    }
    
    func setIndeterminate(_ indeterminate: Bool) {
        DispatchQueue.main.async {
            self.progressBar.isIndeterminate = indeterminate
            if indeterminate {
                self.progressBar.startAnimation(nil)
            } else {
                self.progressBar.stopAnimation(nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatTimeRemaining(_ seconds: Double) -> String {
        if seconds.isInfinite || seconds.isNaN {
            return "Calculating..."
        }
        
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        
        if minutes > 0 {
            return "\(minutes) min \(secs) sec remaining"
        } else {
            return "\(secs) sec remaining"
        }
    }
    
    @objc private func cancelClicked() {
        isCancelled = true
        onCancel?()
        window?.close()
    }
}
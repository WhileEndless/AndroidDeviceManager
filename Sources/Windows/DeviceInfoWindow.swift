import Cocoa

class DeviceInfoWindow: NSWindowController {
    private let device: Device
    private let adbClient: ADBClient
    
    // UI Elements
    private var modelLabel: NSTextField!
    private var androidVersionLabel: NSTextField!
    private var sdkVersionLabel: NSTextField!
    private var serialNumberLabel: NSTextField!
    private var buildNumberLabel: NSTextField!
    private var manufacturerLabel: NSTextField!
    private var brandLabel: NSTextField!
    private var abiLabel: NSTextField!
    private var densityLabel: NSTextField!
    private var resolutionLabel: NSTextField!
    private var refreshButton: NSButton!
    private var exportButton: NSButton!
    
    init(device: Device) {
        self.device = device
        self.adbClient = ADBClient()
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 570),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Device Info - \(device.modelName)"
        window.center()
        self.window = window
        
        setupContent()
        loadDeviceInfo()
    }
    
    private func setupContent() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Device Information")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 20, y: contentView.bounds.height - 50, width: 300, height: 25)
        titleLabel.textColor = .labelColor
        contentView.addSubview(titleLabel)
        
        // Main content area with proper spacing
        let contentY = contentView.bounds.height - 90
        let rowHeight: CGFloat = 32
        let labelWidth: CGFloat = 150
        let valueX: CGFloat = 180
        let valueWidth: CGFloat = 330
        
        var currentY = contentY
        
        // Create info rows with better spacing and alignment
        func addInfoRow(label: String, value: inout NSTextField!) {
            let labelField = NSTextField(labelWithString: label)
            labelField.alignment = .right
            labelField.font = NSFont.systemFont(ofSize: 13)
            labelField.textColor = .secondaryLabelColor
            labelField.frame = NSRect(x: 20, y: currentY, width: labelWidth, height: 20)
            contentView.addSubview(labelField)
            
            value = NSTextField(labelWithString: "Loading...")
            value.isEditable = false
            value.isBordered = false
            value.backgroundColor = .clear
            value.font = NSFont.systemFont(ofSize: 13)
            value.textColor = .labelColor
            value.frame = NSRect(x: valueX, y: currentY, width: valueWidth, height: 20)
            value.isSelectable = true
            contentView.addSubview(value)
            
            currentY -= rowHeight
        }
        
        // Add all info rows with consistent spacing
        addInfoRow(label: "Model:", value: &modelLabel)
        addInfoRow(label: "Manufacturer:", value: &manufacturerLabel)
        addInfoRow(label: "Brand:", value: &brandLabel)
        
        // Add separator
        currentY -= 15
        let separator1 = NSBox(frame: NSRect(x: 20, y: currentY, width: 510, height: 1))
        separator1.boxType = .separator
        contentView.addSubview(separator1)
        currentY -= 25
        
        addInfoRow(label: "Android Version:", value: &androidVersionLabel)
        addInfoRow(label: "SDK Version:", value: &sdkVersionLabel)
        addInfoRow(label: "Build Number:", value: &buildNumberLabel)
        
        // Add separator
        currentY -= 15
        let separator2 = NSBox(frame: NSRect(x: 20, y: currentY, width: 510, height: 1))
        separator2.boxType = .separator
        contentView.addSubview(separator2)
        currentY -= 25
        
        addInfoRow(label: "Serial Number:", value: &serialNumberLabel)
        addInfoRow(label: "CPU ABI:", value: &abiLabel)
        
        // Add separator
        currentY -= 15
        let separator3 = NSBox(frame: NSRect(x: 20, y: currentY, width: 510, height: 1))
        separator3.boxType = .separator
        contentView.addSubview(separator3)
        currentY -= 25
        
        addInfoRow(label: "Screen Density:", value: &densityLabel)
        addInfoRow(label: "Screen Resolution:", value: &resolutionLabel)
        
        // Buttons at the bottom
        refreshButton = NSButton(frame: NSRect(x: 350, y: 25, width: 90, height: 32))
        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshDeviceInfo)
        contentView.addSubview(refreshButton)
        
        exportButton = NSButton(frame: NSRect(x: 445, y: 25, width: 85, height: 32))
        exportButton.title = "Export"
        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportDeviceInfo)
        contentView.addSubview(exportButton)
        
        window?.contentView = contentView
    }
    
    private func loadDeviceInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get device properties
            let properties = [
                ("ro.product.model", self.modelLabel),
                ("ro.product.manufacturer", self.manufacturerLabel),
                ("ro.product.brand", self.brandLabel),
                ("ro.build.version.release", self.androidVersionLabel),
                ("ro.build.version.sdk", self.sdkVersionLabel),
                ("ro.build.display.id", self.buildNumberLabel),
                ("ro.serialno", self.serialNumberLabel),
                ("ro.product.cpu.abi", self.abiLabel),
                ("ro.sf.lcd_density", self.densityLabel)
            ]
            
            for (prop, label) in properties {
                let result = self.adbClient.shell(command: "getprop \(prop)", deviceId: self.device.deviceId)
                let value = result.isSuccess ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : "N/A"
                
                DispatchQueue.main.async {
                    label?.stringValue = value.isEmpty ? "N/A" : value
                }
            }
            
            // Get screen resolution
            let wmSizeResult = self.adbClient.shell(command: "wm size", deviceId: self.device.deviceId)
            if wmSizeResult.isSuccess {
                let sizeOutput = wmSizeResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let sizeRange = sizeOutput.range(of: "Physical size: ") {
                    let resolution = String(sizeOutput[sizeRange.upperBound...])
                    DispatchQueue.main.async {
                        self.resolutionLabel?.stringValue = resolution
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.resolutionLabel?.stringValue = "N/A"
                }
            }
        }
    }
    
    @objc private func refreshDeviceInfo() {
        // Reset all labels to loading
        let labels = [modelLabel, manufacturerLabel, brandLabel, androidVersionLabel, 
                     sdkVersionLabel, buildNumberLabel, serialNumberLabel, abiLabel, 
                     densityLabel, resolutionLabel]
        
        for label in labels {
            label?.stringValue = "Loading..."
        }
        
        loadDeviceInfo()
    }
    
    @objc private func exportDeviceInfo() {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["txt"]
        savePanel.nameFieldStringValue = "device_info_\(device.deviceId).txt"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = savePanel.url, let self = self {
                var content = "Device Information - \(self.device.modelName)\n"
                content += "================================\n\n"
                content += "Model: \(self.modelLabel.stringValue)\n"
                content += "Manufacturer: \(self.manufacturerLabel.stringValue)\n"
                content += "Brand: \(self.brandLabel.stringValue)\n"
                content += "Android Version: \(self.androidVersionLabel.stringValue)\n"
                content += "SDK Version: \(self.sdkVersionLabel.stringValue)\n"
                content += "Build Number: \(self.buildNumberLabel.stringValue)\n"
                content += "Serial Number: \(self.serialNumberLabel.stringValue)\n"
                content += "CPU ABI: \(self.abiLabel.stringValue)\n"
                content += "Screen Density: \(self.densityLabel.stringValue)\n"
                content += "Screen Resolution: \(self.resolutionLabel.stringValue)\n"
                content += "\nExported: \(Date())\n"
                
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    self.showAlert(title: "Export Successful", message: "Device information has been exported.", style: .informational)
                } catch {
                    self.showAlert(title: "Export Failed", message: error.localizedDescription, style: .critical)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
}
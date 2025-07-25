import Cocoa

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var deviceManager: DeviceManager
    private var preferencesWindow: PreferencesWindow?
    private var quickCommandsWindow: QuickCommandsWindow?
    private var portForwardingWindow: PortForwardingWindow?
    private var fridaServersWindow: FridaServersWindow?
    private var logcatViewerWindow: LogcatViewerWindow?
    private var deviceInfoWindow: DeviceInfoWindow?
    private var aboutWindow: AboutWindow?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        deviceManager = DeviceManager()
        
        // Quick setup - show icon immediately
        setupStatusBarItem()
        
        // Show basic menu immediately
        setupInitialMenu()
        
        // Setup notification observer for auto-selected devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceAutoSelected(_:)),
            name: Notification.Name("DeviceAutoSelected"),
            object: nil
        )
        
        // Load devices and start monitoring asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.deviceManager.refreshDevices()
            
            DispatchQueue.main.async {
                self?.updateMenu()
                self?.startDeviceMonitoring()
                
                // Setup automatic port forwarding for active device
                self?.setupAutomaticPortForwarding()
            }
        }
    }
    
    private func setupStatusBarItem() {
        if let button = statusItem.button {
            // Create a simple text-based icon for now
            button.title = "📱"
            button.toolTip = "Android Device Manager"
        }
        statusItem.menu = menu
    }
    
    private func setupMenu() {
        updateMenu()
    }
    
    private func setupInitialMenu() {
        menu.removeAllItems()
        
        // Title
        let titleItem = NSMenuItem(title: "Android Device Manager", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Loading message
        let loadingItem = NSMenuItem(title: "⏳ Loading devices...", action: nil, keyEquivalent: "")
        loadingItem.isEnabled = false
        menu.addItem(loadingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Basic items that don't need device
        menu.addItem(createMenuItem(title: "📁 Open Screenshots Folder", action: #selector(openScreenshotsFolder), keyEquivalent: "", enabled: true))
        menu.addItem(createMenuItem(title: "🔄 Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r", enabled: true))
        
        menu.addItem(NSMenuItem.separator())
        
        // Bottom section
        menu.addItem(createMenuItem(title: "⚙️ Preferences...", action: #selector(showPreferences), keyEquivalent: ",", enabled: true))
        let aboutItem = createMenuItem(title: "ℹ️ About...", action: #selector(showAbout), keyEquivalent: "", enabled: true)
        aboutItem.keyEquivalentModifierMask = []  // Remove all modifiers
        menu.addItem(aboutItem)
        menu.addItem(createMenuItem(title: "🚪 Quit", action: #selector(quitApp), keyEquivalent: "q", enabled: true))
    }
    
    private func updateMenu() {
        menu.removeAllItems()
        
        // Title
        let titleItem = NSMenuItem(title: "Android Device Manager", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Device section
        let devices = deviceManager.getConnectedDevices()
        if devices.isEmpty {
            let noDeviceItem = NSMenuItem(title: "📱 No devices connected", action: nil, keyEquivalent: "")
            noDeviceItem.isEnabled = false
            menu.addItem(noDeviceItem)
        } else {
            for device in devices {
                // Device icon based on authorization status
                let deviceIcon = device.isAuthorized ? "📱" : "🔒"
                
                // Root status icon (only show if authorized and root check completed)
                var statusIcon = ""
                if device.isAuthorized && device.rootCheckCompleted {
                    statusIcon = device.isRooted ? " ⚡" : ""  // Lightning bolt for root
                }
                
                // Show model name or fallback to device ID
                let displayName = (device.modelName.isEmpty || device.modelName == "Unknown Device") ? device.deviceId : device.modelName
                
                let deviceItem = NSMenuItem(
                    title: "\(deviceIcon) \(displayName) (\(device.connectionType.rawValue))\(statusIcon)",
                    action: #selector(selectDevice(_:)),
                    keyEquivalent: ""
                )
                deviceItem.target = self
                deviceItem.representedObject = device
                deviceItem.state = device.isActive ? .on : .off
                
                // Add tooltip for unauthorized devices
                if !device.isAuthorized {
                    deviceItem.toolTip = "Device not authorized. Please check your device and allow USB debugging."
                }
                
                menu.addItem(deviceItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Refresh devices option
        menu.addItem(createMenuItem(title: "🔄 Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r", enabled: true))
        
        menu.addItem(NSMenuItem.separator())
        
        // Features - only enabled if device is connected
        let hasActiveDevice = deviceManager.activeDevice != nil
        let isRooted = deviceManager.activeDevice?.isRooted ?? false
        
        // Screenshot menu item
        menu.addItem(createMenuItem(title: "📸 Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "s", enabled: hasActiveDevice))
        menu.addItem(createMenuItem(title: "📁 Open Screenshots Folder", action: #selector(openScreenshotsFolder), keyEquivalent: "", enabled: true))
        
        // Clipboard menu item - directly send to device
        let sendItem = createMenuItem(title: "📋 Send Clipboard to Device", action: #selector(sendClipboard), keyEquivalent: "v", enabled: hasActiveDevice)
        sendItem.toolTip = "Type macOS clipboard content into the focused field on Android"
        menu.addItem(sendItem)
        
        // Shell submenu
        let shellItem = NSMenuItem(title: "🖥️ Shell", action: nil, keyEquivalent: "")
        let shellSubmenu = NSMenu()
        shellSubmenu.addItem(createMenuItem(title: "Open Terminal", action: #selector(openShell), keyEquivalent: "t", enabled: hasActiveDevice))
        shellSubmenu.addItem(createMenuItem(title: "Quick Commands...", action: #selector(showQuickCommands), keyEquivalent: "", enabled: hasActiveDevice))
        shellItem.submenu = shellSubmenu
        menu.addItem(shellItem)
        
        // Direct menu items
        menu.addItem(createMenuItem(title: "🔀 Port Forwarding...", action: #selector(showPortForwarding), keyEquivalent: "", enabled: hasActiveDevice))
        
        // Frida requires root
        let fridaItem = createMenuItem(title: "🔧 Frida Servers...", action: #selector(showFridaServers), keyEquivalent: "", enabled: hasActiveDevice && isRooted)
        if hasActiveDevice && !isRooted {
            fridaItem.toolTip = "Requires root access"
        }
        menu.addItem(fridaItem)
        
        menu.addItem(createMenuItem(title: "📋 View Logs...", action: #selector(showLogs), keyEquivalent: "", enabled: hasActiveDevice))
        menu.addItem(createMenuItem(title: "ℹ️ Device Info...", action: #selector(showDeviceInfo), keyEquivalent: "", enabled: hasActiveDevice))
        
        menu.addItem(NSMenuItem.separator())
        
        // Bottom section
        menu.addItem(createMenuItem(title: "⚙️ Preferences...", action: #selector(showPreferences), keyEquivalent: ",", enabled: true))
        let aboutItem = createMenuItem(title: "ℹ️ About...", action: #selector(showAbout), keyEquivalent: "", enabled: true)
        aboutItem.keyEquivalentModifierMask = []  // Remove all modifiers
        menu.addItem(aboutItem)
        menu.addItem(createMenuItem(title: "🚪 Quit", action: #selector(quitApp), keyEquivalent: "q", enabled: true))
    }
    
    private func createMenuItem(title: String, action: Selector?, keyEquivalent: String, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = enabled
        return item
    }
    
    private func startDeviceMonitoring() {
        // Start monitoring for device changes
        // Check every 10 seconds for better responsiveness
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.checkForDeviceChanges()
            }
        }
    }
    
    private func checkForDeviceChanges() {
        let previousCount = deviceManager.getConnectedDevices().count
        let previousActiveDevice = deviceManager.activeDevice
        
        // Only refresh if devices actually changed
        if deviceManager.checkDeviceChanges() {
            deviceManager.refreshDevices()
            let currentCount = deviceManager.getConnectedDevices().count
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMenu()
                
                // Show notification for device changes
                if currentCount > previousCount {
                    self?.showNotification(title: "Device Connected", message: "New Android device detected")
                    
                    // If this is the first device and we didn't have an active device, setup port forwarding
                    if previousCount == 0 && previousActiveDevice == nil && self?.deviceManager.activeDevice != nil {
                        self?.setupAutomaticPortForwarding()
                    }
                } else if currentCount < previousCount {
                    self?.showNotification(title: "Device Disconnected", message: "Android device disconnected")
                }
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Actions
    
    @objc private func refreshDevices() {
        // Show loading state
        if let loadingItem = menu.item(withTitle: "📱 No devices connected") {
            loadingItem.title = "⏳ Refreshing devices..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.deviceManager.refreshDevices()
            
            DispatchQueue.main.async {
                self?.updateMenu()
                
                let deviceCount = self?.deviceManager.getConnectedDevices().count ?? 0
                if deviceCount == 0 {
                    self?.showNotification(title: "No Devices", message: "No Android devices found")
                } else {
                    self?.showNotification(title: "Devices Refreshed", message: "\(deviceCount) device(s) found")
                }
            }
        }
    }
    
    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? Device else { return }
        deviceManager.selectDevice(device.deviceId)
        updateMenu()
        
        // Setup automatic port forwarding for newly selected device
        setupAutomaticPortForwarding()
    }
    
    @objc private func takeScreenshot() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        let screenshotManager = ScreenshotManager(device: device, adbClient: ADBClient())
        
        showNotification(title: "Screenshot", message: "Capturing screenshot...")
        
        screenshotManager.captureScreenshot { [weak self] result in
            switch result {
            case .success(let url):
                self?.showNotification(title: "Screenshot Captured", message: url.lastPathComponent)
                screenshotManager.openInDefaultEditor(at: url)
            case .failure(let error):
                self?.showNotification(title: "Screenshot Failed", message: error.localizedDescription)
            }
        }
    }
    
    
    @objc private func openScreenshotsFolder() {
        let screenshotsPath = Preferences.shared.screenshotDirectory
        NSWorkspace.shared.open(URL(fileURLWithPath: screenshotsPath))
    }
    
    @objc private func sendClipboard() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        let clipboardManager = ClipboardManager(device: device, adbClient: ADBClient())
        
        clipboardManager.sendToDevice { [weak self] result in
            switch result {
            case .success:
                self?.showNotification(title: "Clipboard Sent", message: "Clipboard content sent to device")
            case .failure(let error):
                self?.showNotification(title: "Clipboard Error", message: error.localizedDescription)
            }
        }
    }
    
    
    @objc private func openShell() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        let shellManager = ShellManager(device: device)
        shellManager.openShellInTerminal()
    }
    
    @objc private func showQuickCommands() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        quickCommandsWindow = QuickCommandsWindow(device: device)
        quickCommandsWindow?.showWindow(nil)
        quickCommandsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showPortForwarding() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        portForwardingWindow = PortForwardingWindow(device: device)
        portForwardingWindow?.showWindow(nil)
        portForwardingWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showFridaServers() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        guard device.isRooted else {
            showNotification(title: "Root Required", message: "Frida servers require root access")
            return
        }
        
        fridaServersWindow = FridaServersWindow(device: device)
        fridaServersWindow?.showWindow(nil)
        fridaServersWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showLogs() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        logcatViewerWindow = LogcatViewerWindow(device: device)
        logcatViewerWindow?.showWindow(nil)
        logcatViewerWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showDeviceInfo() {
        guard let device = deviceManager.activeDevice else {
            showNotification(title: "Error", message: "No active device")
            return
        }
        
        deviceInfoWindow = DeviceInfoWindow(device: device)
        deviceInfoWindow?.showWindow(nil)
        deviceInfoWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow(window: nil)
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        if aboutWindow == nil {
            aboutWindow = AboutWindow(window: nil)
        }
        aboutWindow?.showWindow(nil)
        aboutWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func deviceAutoSelected(_ notification: Notification) {
        // When a device is auto-selected (first device when no active device), setup port forwarding
        DispatchQueue.main.async { [weak self] in
            self?.setupAutomaticPortForwarding()
        }
    }
    
    // MARK: - Automatic Port Forwarding
    
    private func setupAutomaticPortForwarding() {
        // Only setup for active device
        guard let activeDevice = deviceManager.activeDevice else {
            print("No active device for automatic port forwarding")
            return
        }
        
        print("Setting up automatic port forwarding for device: \(activeDevice.modelName)")
        
        // Check if reverse port 8080 is already set up
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let adbClient = ADBClient()
            
            // Check existing reverse ports
            let reverseList = adbClient.executeCommand(
                args: ["reverse", "--list"],
                deviceId: activeDevice.deviceId
            )
            
            let hasPort8080 = reverseList.isSuccess && reverseList.output.contains("tcp:8080")
            
            if !hasPort8080 {
                // Setup reverse port forwarding for 8080
                let result = adbClient.reverse(
                    remotePort: 8080,
                    localPort: 8080,
                    deviceId: activeDevice.deviceId
                )
                
                DispatchQueue.main.async {
                    if result.isSuccess {
                        print("Successfully set up reverse port forwarding for port 8080")
                        self.showNotification(
                            title: "Port Forwarding Active",
                            message: "Reverse port 8080 enabled for \(activeDevice.modelName)"
                        )
                    } else {
                        print("Failed to set up reverse port forwarding: \(result.error)")
                    }
                }
            } else {
                print("Reverse port 8080 already configured")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
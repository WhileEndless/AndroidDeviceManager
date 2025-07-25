import Foundation

class DeviceManager: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var activeDevice: Device?
    
    let adbClient: ADBClient
    
    init() {
        self.adbClient = ADBClient()
        // Don't refresh devices on init - let it be done asynchronously after app starts
    }
    
    func getConnectedDevices() -> [Device] {
        return devices
    }
    
    // Lightweight check - only runs 'adb devices' without fetching all properties
    func checkDeviceChanges() -> Bool {
        let connectedDevices = adbClient.getDevices()
        let currentDeviceIds = Set(connectedDevices.map { $0.id })
        let existingDeviceIds = Set(devices.map { $0.deviceId })
        
        // Return true if device list changed
        return currentDeviceIds != existingDeviceIds
    }
    
    func refreshDevices() {
        let connectedDevices = adbClient.getDevices()
        
        // Update existing devices or add new ones
        var updatedDevices: [Device] = []
        
        // Process all devices
        for deviceInfo in connectedDevices {
            let deviceId = deviceInfo.id
            let isAuthorized = !deviceInfo.status.contains("unauthorized")
            
            if let existingDevice = devices.first(where: { $0.deviceId == deviceId }) {
                // Update existing device
                var device = existingDevice
                device.isAuthorized = isAuthorized
                updateDeviceInfo(&device)
                updatedDevices.append(device)
            } else {
                // Create new device
                var device = Device(deviceId: deviceId, serialNumber: deviceId)
                device.isAuthorized = isAuthorized
                updateDeviceInfo(&device)
                updatedDevices.append(device)
            }
        }
        
        // Handle disconnected devices
        let currentDeviceIds = Set(updatedDevices.map { $0.deviceId })
        let previousDeviceIds = Set(devices.map { $0.deviceId })
        
        // Find disconnected devices
        let disconnectedDeviceIds = previousDeviceIds.subtracting(currentDeviceIds)
        for deviceId in disconnectedDeviceIds {
            ShellSessionManager.shared.handleDeviceDisconnected(deviceId)
        }
        
        // Find newly connected devices
        let newDeviceIds = currentDeviceIds.subtracting(previousDeviceIds)
        for deviceId in newDeviceIds {
            ShellSessionManager.shared.handleDeviceConnected(deviceId)
        }
        
        // Update devices array
        devices = updatedDevices
        
        // If active device is no longer connected, clear it
        if let activeDevice = activeDevice,
           !devices.contains(where: { $0.deviceId == activeDevice.deviceId }) {
            self.activeDevice = nil
        }
        
        // If no active device but devices are available, select the first one
        if activeDevice == nil && !devices.isEmpty {
            selectDevice(devices[0].deviceId)
            
            // Post notification that a new device was selected
            NotificationCenter.default.post(name: Notification.Name("DeviceAutoSelected"), object: devices[0])
        }
    }
    
    func selectDevice(_ deviceId: String) {
        // Deactivate all devices
        for i in 0..<devices.count {
            devices[i].isActive = false
        }
        
        // Activate selected device
        if let index = devices.firstIndex(where: { $0.deviceId == deviceId }) {
            devices[index].isActive = true
            activeDevice = devices[index]
        }
    }
    
    func executeCommand(command: String) -> String {
        guard let device = activeDevice else {
            return "No active device"
        }
        
        let result = adbClient.shell(command: command, deviceId: device.deviceId)
        return result.isSuccess ? result.output : result.error
    }
    
    private func updateDeviceInfo(_ device: inout Device) {
        let deviceId = device.deviceId
        
        // Determine connection type first
        if deviceId.contains(":") {
            device.connectionType = .wifi
            device.ipAddress = String(deviceId.split(separator: ":")[0])
        } else {
            device.connectionType = .usb
        }
        
        device.lastConnected = Date()
        
        // If authorized, create session first, then get info through the session
        if device.isAuthorized {
            // Pre-warm the session - this will also check root
            if let session = ShellSessionManager.shared.getOrCreateSession(for: deviceId) {
                // Now get model name through the persistent session
                if device.modelName.isEmpty || device.modelName == "Unknown Device" {
                    let modelResult = adbClient.shell(command: "getprop ro.product.model", deviceId: deviceId, persistent: true)
                    if modelResult.isSuccess {
                        let model = modelResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !model.isEmpty {
                            device.modelName = model
                        }
                    }
                }
                
                // Update root status from session
                device.isRooted = session.isRoot
                device.rootCheckCompleted = true
            }
        }
    }
    
    // This method is no longer needed - root status is now checked in updateDeviceInfo
    private func checkRootStatus(_ device: inout Device) {
        // Deprecated - kept for compatibility
    }
    
    // Load full device info only when needed
    func loadFullDeviceInfo(_ deviceId: String) {
        guard let index = devices.firstIndex(where: { $0.deviceId == deviceId }) else { return }
        
        var device = devices[index]
        
        if let androidVersion = adbClient.getProperty(property: "ro.build.version.release", deviceId: deviceId) {
            device.androidVersion = androidVersion
        }
        
        if let sdkVersionStr = adbClient.getProperty(property: "ro.build.version.sdk", deviceId: deviceId),
           let sdkVersion = Int(sdkVersionStr) {
            device.sdkVersion = sdkVersion
        }
        
        if let buildNumber = adbClient.getProperty(property: "ro.build.display.id", deviceId: deviceId) {
            device.buildNumber = buildNumber
        }
        
        devices[index] = device
        
        if device.isActive {
            activeDevice = device
        }
    }
    
    func getDetailedDeviceInfo() -> DeviceInfo? {
        guard let device = activeDevice else { return nil }
        
        let deviceId = device.deviceId
        
        return DeviceInfo(
            manufacturer: adbClient.getProperty(property: "ro.product.manufacturer", deviceId: deviceId) ?? "Unknown",
            brand: adbClient.getProperty(property: "ro.product.brand", deviceId: deviceId) ?? "Unknown",
            model: device.modelName,
            androidVersion: device.androidVersion,
            sdkVersion: String(device.sdkVersion),
            buildId: device.buildNumber,
            cpuAbi: adbClient.getProperty(property: "ro.product.cpu.abi", deviceId: deviceId) ?? "Unknown",
            screenDensity: adbClient.getProperty(property: "ro.sf.lcd_density", deviceId: deviceId) ?? "Unknown",
            screenResolution: getScreenResolution(deviceId: deviceId),
            totalMemory: getMemoryInfo(deviceId: deviceId).total,
            availableMemory: getMemoryInfo(deviceId: deviceId).available,
            totalStorage: getStorageInfo(deviceId: deviceId).total,
            availableStorage: getStorageInfo(deviceId: deviceId).available
        )
    }
    
    private func getScreenResolution(deviceId: String) -> String {
        let result = adbClient.shell(command: "wm size", deviceId: deviceId)
        if result.isSuccess {
            // Parse "Physical size: 1080x2340"
            if let range = result.output.range(of: "Physical size: ") {
                let resolution = result.output[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return String(resolution)
            }
        }
        return "Unknown"
    }
    
    private func getMemoryInfo(deviceId: String) -> (total: String, available: String) {
        let result = adbClient.shell(command: "cat /proc/meminfo", deviceId: deviceId)
        var total = "Unknown"
        var available = "Unknown"
        
        if result.isSuccess {
            let lines = result.output.split(separator: "\n")
            for line in lines {
                if line.hasPrefix("MemTotal:") {
                    let components = line.split(separator: " ").compactMap { String($0) }
                    if components.count >= 2 {
                        if let kb = Int(components[1]) {
                            total = formatBytes(kb * 1024)
                        }
                    }
                } else if line.hasPrefix("MemAvailable:") {
                    let components = line.split(separator: " ").compactMap { String($0) }
                    if components.count >= 2 {
                        if let kb = Int(components[1]) {
                            available = formatBytes(kb * 1024)
                        }
                    }
                }
            }
        }
        
        return (total, available)
    }
    
    private func getStorageInfo(deviceId: String) -> (total: String, available: String) {
        let result = adbClient.shell(command: "df -h /data", deviceId: deviceId)
        var total = "Unknown"
        var available = "Unknown"
        
        if result.isSuccess {
            let lines = result.output.split(separator: "\n")
            if lines.count >= 2 {
                let components = lines[1].split(separator: " ").compactMap { String($0) }
                if components.count >= 4 {
                    total = components[1]
                    available = components[3]
                }
            }
        }
        
        return (total, available)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
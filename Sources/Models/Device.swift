import Foundation

enum ConnectionType: String {
    case usb = "USB"
    case wifi = "WiFi"
}

struct Device: Identifiable, Equatable {
    let id = UUID()
    let deviceId: String
    let serialNumber: String
    var modelName: String
    var androidVersion: String
    var sdkVersion: Int
    var buildNumber: String
    var isRooted: Bool
    var rootCheckCompleted: Bool
    var isAuthorized: Bool
    var connectionType: ConnectionType
    var ipAddress: String?
    var lastConnected: Date
    var isActive: Bool
    
    init(deviceId: String, serialNumber: String) {
        self.deviceId = deviceId
        self.serialNumber = serialNumber
        self.modelName = "Unknown Device"
        self.androidVersion = "Unknown"
        self.sdkVersion = 0
        self.buildNumber = "Unknown"
        self.isRooted = false
        self.rootCheckCompleted = false
        self.isAuthorized = true  // Default to true, will be updated based on status
        self.connectionType = .usb
        self.ipAddress = nil
        self.lastConnected = Date()
        self.isActive = false
    }
    
    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.deviceId == rhs.deviceId
    }
}

struct DeviceInfo {
    let manufacturer: String
    let brand: String
    let model: String
    let androidVersion: String
    let sdkVersion: String
    let buildId: String
    let cpuAbi: String
    let screenDensity: String
    let screenResolution: String
    let totalMemory: String
    let availableMemory: String
    let totalStorage: String
    let availableStorage: String
}
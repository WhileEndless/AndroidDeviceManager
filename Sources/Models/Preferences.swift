import Foundation

class Preferences {
    static let shared = Preferences()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys
    private let screenshotDirectoryKey = "screenshotDirectory"
    private let adbPathKey = "adbPath"
    private let autoConnectKey = "autoConnect"
    private let downloadDirectoryKey = "downloadDirectory"
    
    private init() {
        registerDefaults()
    }
    
    private func registerDefaults() {
        let defaults: [String: Any] = [
            screenshotDirectoryKey: NSString(string: "~/Pictures/AndroidScreenshots").expandingTildeInPath,
            adbPathKey: "/usr/local/bin/adb",
            autoConnectKey: true,
            downloadDirectoryKey: NSString(string: "~/Downloads").expandingTildeInPath
        ]
        userDefaults.register(defaults: defaults)
    }
    
    // Screenshot directory
    var screenshotDirectory: String {
        get {
            return userDefaults.string(forKey: screenshotDirectoryKey) ?? NSString(string: "~/Pictures/AndroidScreenshots").expandingTildeInPath
        }
        set {
            userDefaults.set(newValue, forKey: screenshotDirectoryKey)
        }
    }
    
    // ADB path
    var adbPath: String {
        get {
            return userDefaults.string(forKey: adbPathKey) ?? "/usr/local/bin/adb"
        }
        set {
            userDefaults.set(newValue, forKey: adbPathKey)
        }
    }
    
    // Auto connect
    var autoConnect: Bool {
        get {
            return userDefaults.bool(forKey: autoConnectKey)
        }
        set {
            userDefaults.set(newValue, forKey: autoConnectKey)
        }
    }
    
    // Download directory
    var downloadDirectory: String {
        get {
            return userDefaults.string(forKey: downloadDirectoryKey) ?? NSString(string: "~/Downloads").expandingTildeInPath
        }
        set {
            userDefaults.set(newValue, forKey: downloadDirectoryKey)
        }
    }
    
    // Reset to defaults
    func resetToDefaults() {
        userDefaults.removeObject(forKey: screenshotDirectoryKey)
        userDefaults.removeObject(forKey: adbPathKey)
        userDefaults.removeObject(forKey: autoConnectKey)
        userDefaults.removeObject(forKey: downloadDirectoryKey)
        registerDefaults()
    }
}
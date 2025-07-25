import Foundation

struct AppInfo {
    static let name = "Android Device Manager"
    static let version = "1.0.1"
    static let build = "101"
    static let copyright = "© 2025 WhileEndless"
    static let githubURL = "https://github.com/WhileEndless/AndroidDeviceManager"
    static let description = "A powerful macOS menu bar application for managing Android devices via ADB"
    
    static var fullVersion: String {
        return "\(version) (\(build))"
    }
}
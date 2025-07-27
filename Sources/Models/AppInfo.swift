import Foundation

struct AppInfo {
    static let name = "Android Device Manager"
    static let version = "1.3.0"
    static let build = "130"
    static let copyright = "© 2025 WhileEndless"
    static let githubURL = "https://github.com/WhileEndless/AndroidDeviceManager"
    static let description = "A powerful macOS menu bar application for managing Android devices via ADB"
    
    static var fullVersion: String {
        return "\(version) (\(build))"
    }
}
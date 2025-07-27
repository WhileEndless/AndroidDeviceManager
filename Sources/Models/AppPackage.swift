import Foundation

struct AppPackage: Identifiable, Equatable {
    let id = UUID()
    let packageName: String
    var appName: String
    var versionName: String
    var versionCode: String
    var apkPaths: [String]
    var isSystemApp: Bool
    var isEnabled: Bool
    var installedSize: Int64
    
    init(packageName: String) {
        self.packageName = packageName
        self.appName = packageName
        self.versionName = ""
        self.versionCode = ""
        self.apkPaths = []
        self.isSystemApp = false
        self.isEnabled = true
        self.installedSize = 0
    }
    
    static func == (lhs: AppPackage, rhs: AppPackage) -> Bool {
        return lhs.packageName == rhs.packageName
    }
    
    var displayName: String {
        return appName.isEmpty ? packageName : appName
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: installedSize)
    }
    
    var isSplitApk: Bool {
        return apkPaths.count > 1
    }
}
import Foundation
import AppKit

class AppManager {
    private let adbClient: ADBClient
    private let deviceId: String
    
    init(deviceId: String) {
        self.deviceId = deviceId
        self.adbClient = ADBClient()
    }
    
    func getInstalledApps(includeSystemApps: Bool = false) -> [AppPackage] {
        let packageNames = adbClient.listPackages(deviceId: deviceId, includeSystemApps: includeSystemApps)
        var apps: [AppPackage] = []
        
        for packageName in packageNames {
            var app = AppPackage(packageName: packageName)
            // Extract simple app name from package name for display
            app.appName = packageName.split(separator: ".").last.map(String.init) ?? packageName
            apps.append(app)
        }
        
        return apps.sorted { $0.packageName.lowercased() < $1.packageName.lowercased() }
    }
    
    private func loadPackageDetails(for package: inout AppPackage) {
        // Get package info
        if let info = adbClient.getPackageInfo(packageName: package.packageName, deviceId: deviceId) {
            package.appName = info.appName
            package.versionName = info.versionName
            package.versionCode = info.versionCode
        }
        
        // Get APK paths
        package.apkPaths = adbClient.getPackagePath(packageName: package.packageName, deviceId: deviceId)
        
        // Determine if system app
        package.isSystemApp = package.apkPaths.contains { path in
            path.contains("/system/") || path.contains("/vendor/") || path.contains("/product/")
        }
    }
    
    func exportAPK(package: AppPackage, completion: @escaping (Bool, String?) -> Void) {
        // Load package details first if not already loaded
        var detailedPackage = package
        if detailedPackage.apkPaths.isEmpty {
            loadPackageDetails(for: &detailedPackage)
        }
        
        let downloadDir = Preferences.shared.downloadDirectory
        let packageDir = "\(downloadDir)/\(detailedPackage.packageName)"
        
        // Create directory for the package
        do {
            try FileManager.default.createDirectory(
                atPath: packageDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            completion(false, "Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        // Export all APK files
        var exportedFiles: [String] = []
        var hasError = false
        var errorMessage = ""
        
        for (index, apkPath) in detailedPackage.apkPaths.enumerated() {
            let fileName: String
            if detailedPackage.isSplitApk {
                // For split APKs, use descriptive names
                let pathComponents = apkPath.split(separator: "/")
                if let apkName = pathComponents.last {
                    fileName = String(apkName)
                } else {
                    fileName = "split_\(index).apk"
                }
            } else {
                // For single APK, use package name
                fileName = "\(detailedPackage.packageName).apk"
            }
            
            let localPath = "\(packageDir)/\(fileName)"
            
            print("[AppManager] Exporting APK:")
            print("[AppManager]   Package: \(detailedPackage.packageName)")
            print("[AppManager]   Remote: \(apkPath)")
            print("[AppManager]   Local: \(localPath)")
            
            let result = adbClient.pullFile(remotePath: apkPath, localPath: localPath, deviceId: deviceId)
            
            if result.isSuccess {
                exportedFiles.append(localPath)
                print("[AppManager]   Success!")
            } else {
                hasError = true
                errorMessage = "Failed to export \(fileName): \(result.error)"
                print("[AppManager]   Failed: \(result.error)")
                break
            }
        }
        
        if hasError {
            // Clean up partial exports
            for file in exportedFiles {
                try? FileManager.default.removeItem(atPath: file)
            }
            try? FileManager.default.removeItem(atPath: packageDir)
            completion(false, errorMessage)
        } else {
            // Open the directory in Finder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: packageDir)
            completion(true, packageDir)
        }
    }
    
    func exportAPKWithProgress(package: AppPackage, progressHandler: @escaping (Double, String) -> Void, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load package details first if not already loaded
            var detailedPackage = package
            if detailedPackage.apkPaths.isEmpty {
                DispatchQueue.main.async {
                    progressHandler(0.1, "Loading package details...")
                }
                self.loadPackageDetails(for: &detailedPackage)
            }
            
            let downloadDir = Preferences.shared.downloadDirectory
            let packageDir = "\(downloadDir)/\(detailedPackage.packageName)"
            
            // Create directory for the package
            do {
                try FileManager.default.createDirectory(
                    atPath: packageDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to create directory: \(error.localizedDescription)")
                }
                return
            }
            
            let totalFiles = detailedPackage.apkPaths.count
            var exportedFiles: [String] = []
            var hasError = false
            var errorMessage = ""
            
            for (index, apkPath) in detailedPackage.apkPaths.enumerated() {
                let fileName: String
                if detailedPackage.isSplitApk {
                    let pathComponents = apkPath.split(separator: "/")
                    if let apkName = pathComponents.last {
                        fileName = String(apkName)
                    } else {
                        fileName = "split_\(index).apk"
                    }
                } else {
                    fileName = "\(detailedPackage.packageName).apk"
                }
                
                let localPath = "\(packageDir)/\(fileName)"
                
                DispatchQueue.main.async {
                    let progress = Double(index) / Double(totalFiles)
                    progressHandler(progress, "Exporting \(fileName)...")
                }
                
                let result = self.adbClient.pullFile(remotePath: apkPath, localPath: localPath, deviceId: self.deviceId)
                
                if result.isSuccess {
                    exportedFiles.append(localPath)
                } else {
                    hasError = true
                    errorMessage = "Failed to export \(fileName): \(result.error)"
                    break
                }
            }
            
            DispatchQueue.main.async {
                if hasError {
                    // Clean up partial exports
                    for file in exportedFiles {
                        try? FileManager.default.removeItem(atPath: file)
                    }
                    try? FileManager.default.removeItem(atPath: packageDir)
                    completion(false, errorMessage)
                } else {
                    progressHandler(1.0, "Export completed!")
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: packageDir)
                    completion(true, packageDir)
                }
            }
        }
    }
}
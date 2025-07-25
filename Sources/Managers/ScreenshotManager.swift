import Foundation
import Cocoa

class ScreenshotManager {
    private let device: Device
    private let adbClient: ADBClient
    private let storageManager: StorageManager
    
    init(device: Device, adbClient: ADBClient) {
        self.device = device
        self.adbClient = adbClient
        self.storageManager = StorageManager()
    }
    
    func captureScreenshot(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: " ", with: "_")
            
            let filename = "screenshot_\(timestamp).png"
            let outputPath = storageManager.getScreenshotPath(filename: filename)
            
            let result = adbClient.screencap(outputPath: outputPath, deviceId: device.deviceId)
            
            DispatchQueue.main.async {
                if result.isSuccess {
                    completion(.success(URL(fileURLWithPath: outputPath)))
                } else {
                    let error = NSError(
                        domain: "ScreenshotManager",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: result.error]
                    )
                    completion(.failure(error))
                }
            }
        }
    }
    
    func openInDefaultEditor(at url: URL) {
        NSWorkspace.shared.open(url)
    }
}


class StorageManager {
    private var screenshotsDirectory: String {
        return Preferences.shared.screenshotDirectory
    }
    
    init() {
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            atPath: screenshotsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    func getScreenshotPath(filename: String) -> String {
        return (screenshotsDirectory as NSString).appendingPathComponent(filename)
    }
}
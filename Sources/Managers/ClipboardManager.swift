import Foundation
import Cocoa

class ClipboardManager {
    private let device: Device
    private let adbClient: ADBClient
    
    init(device: Device, adbClient: ADBClient) {
        self.device = device
        self.adbClient = adbClient
    }
    
    func sendToDevice(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let content = PasteboardManager.shared.getContent() else {
            completion(.failure(ClipboardError.emptyClipboard))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Use the simple method like in Python
            let result = adbClient.sendTextToDevice(text: content, deviceId: device.deviceId)
            
            DispatchQueue.main.async {
                if result.isSuccess {
                    completion(.success(()))
                } else {
                    completion(.failure(ClipboardError.sendFailed(result.error.isEmpty ? "Failed to send text" : result.error)))
                }
            }
        }
    }
    
}

enum ClipboardError: LocalizedError {
    case emptyClipboard
    case sendFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyClipboard:
            return "Clipboard is empty"
        case .sendFailed(let error):
            return "Failed to send to device: \(error)"
        }
    }
}

class PasteboardManager {
    static let shared = PasteboardManager()
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    func getContent() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    func setContent(_ content: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
    }
    
    func hasContent() -> Bool {
        return pasteboard.string(forType: .string) != nil
    }
}
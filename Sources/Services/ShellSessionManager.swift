import Foundation
import Cocoa

class ShellSessionManager {
    static let shared = ShellSessionManager()
    
    private var sessions: [String: ShellSession] = [:]
    private let sessionQueue = DispatchQueue(label: "shellSessionManager", attributes: .concurrent)
    private let adbPath: String
    
    private init() {
        self.adbPath = Preferences.shared.adbPath
        
        // Clean up sessions when app terminates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        closeAllSessions()
    }
    
    // MARK: - Session Management
    
    func getOrCreateSession(for deviceId: String) -> ShellSession? {
        // Read existing session
        var existingSession: ShellSession?
        sessionQueue.sync {
            existingSession = sessions[deviceId]
        }
        
        // Check if existing session is alive
        if let session = existingSession, session.isAlive {
            return session
        }
        
        // Create new session with write lock
        return sessionQueue.sync(flags: .barrier) {
            // Double-check in case another thread created it
            if let session = sessions[deviceId], session.isAlive {
                return session
            }
            
            // Create new session
            let session = ShellSession(deviceId: deviceId, adbPath: adbPath)
            do {
                try session.start()
                sessions[deviceId] = session
                print("[ShellSessionManager] Created new session for device: \(deviceId)")
                return session
            } catch {
                print("[ShellSessionManager] Failed to start session for device \(deviceId): \(error)")
                return nil
            }
        }
    }
    
    func executeCommand(deviceId: String, command: String, requiresRoot: Bool = false, timeout: TimeInterval = 5.0) -> CommandResult {
        guard let session = getOrCreateSession(for: deviceId) else {
            return CommandResult(
                output: "",
                error: "Failed to create shell session for device \(deviceId)",
                exitCode: -1
            )
        }
        
        // Check root requirement
        if requiresRoot && !session.isRoot {
            return CommandResult(
                output: "",
                error: "Root access required but not available on device",
                exitCode: 1
            )
        }
        
        return session.executeCommand(command, timeout: timeout)
    }
    
    func closeSession(deviceId: String) {
        sessionQueue.sync(flags: .barrier) {
            if let session = sessions[deviceId] {
                session.close()
                sessions.removeValue(forKey: deviceId)
                print("[ShellSessionManager] Closed session for device: \(deviceId)")
            }
        }
    }
    
    func closeAllSessions() {
        sessionQueue.sync(flags: .barrier) {
            for (deviceId, session) in sessions {
                session.close()
                print("[ShellSessionManager] Closed session for device: \(deviceId)")
            }
            sessions.removeAll()
        }
    }
    
    func hasActiveSession(for deviceId: String) -> Bool {
        return sessionQueue.sync {
            sessions[deviceId]?.isAlive ?? false
        }
    }
    
    func isRootAvailable(for deviceId: String) -> Bool {
        return sessionQueue.sync {
            sessions[deviceId]?.isRoot ?? false
        }
    }
    
    // MARK: - Device Management
    
    func handleDeviceDisconnected(_ deviceId: String) {
        closeSession(deviceId: deviceId)
    }
    
    func handleDeviceConnected(_ deviceId: String) {
        // Pre-warm session for better performance
        DispatchQueue.global(qos: .background).async {
            _ = self.getOrCreateSession(for: deviceId)
        }
    }
    
    // MARK: - Lifecycle
    
    @objc private func applicationWillTerminate() {
        closeAllSessions()
    }
}

// MARK: - Debug Extensions

extension ShellSessionManager {
    func printSessionStatus() {
        sessionQueue.sync {
            print("=== Shell Session Status ===")
            print("Active sessions: \(sessions.count)")
            for (deviceId, session) in sessions {
                print("Device: \(deviceId)")
                print("  - Alive: \(session.isAlive)")
                print("  - Root: \(session.isRoot)")
            }
            print("========================")
        }
    }
}
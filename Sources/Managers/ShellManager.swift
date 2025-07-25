import Foundation
import Cocoa

class ShellManager {
    private let device: Device
    private let adbPath: String
    
    init(device: Device) {
        self.device = device
        self.adbPath = Preferences.shared.adbPath
    }
    
    func openShellInTerminal() {
        // ADB shell komutunu oluştur
        let command = "\(adbPath) -s \(device.deviceId) shell"
        
        // First try using open command with Terminal.app
        let openCommand = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        // Create a temporary AppleScript file
        let tempDir = NSTemporaryDirectory()
        let scriptPath = (tempDir as NSString).appendingPathComponent("adb_shell_\(UUID().uuidString).scpt")
        
        do {
            try openCommand.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Execute using osascript
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptPath]
            
            try process.run()
            
            // Clean up after a delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                try? FileManager.default.removeItem(atPath: scriptPath)
            }
            
        } catch {
            print("Error opening terminal with osascript: \(error)")
            
            // Fallback: Try URL scheme approach
            openShellUsingURLScheme()
        }
    }
    
    private func openShellUsingURLScheme() {
        // Create a shell script that will run our adb command
        let shellScript = """
        #!/bin/bash
        clear
        echo "Connecting to \(device.modelName)..."
        "\(adbPath)" -s \(device.deviceId) shell
        """
        
        let tempDir = NSTemporaryDirectory()
        let scriptPath = (tempDir as NSString).appendingPathComponent("adb_shell_\(UUID().uuidString).sh")
        
        do {
            try shellScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            
            // Open Terminal with the script
            let url = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [scriptPath]
            
            NSWorkspace.shared.open(url, configuration: configuration) { (app, error) in
                if let error = error {
                    print("Error opening Terminal app: \(error)")
                    // Final fallback
                    self.openShellUsingOpenCommand()
                } else {
                    // Clean up the script after a delay
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                        try? FileManager.default.removeItem(atPath: scriptPath)
                    }
                }
            }
        } catch {
            print("Error creating shell script: \(error)")
            // Final fallback
            openShellUsingOpenCommand()
        }
    }
    
    private func openShellUsingOpenCommand() {
        // Most reliable method: use 'open' command with Terminal
        let tempDir = NSTemporaryDirectory()
        let commandFile = (tempDir as NSString).appendingPathComponent("adb_\(UUID().uuidString).command")
        
        let shellContent = """
        #!/bin/bash
        cd ~
        clear
        echo "Android Device Manager - Shell Session"
        echo "Device: \(device.modelName) (\(device.deviceId))"
        echo "----------------------------------------"
        echo ""
        "\(adbPath)" -s \(device.deviceId) shell
        echo ""
        echo "Shell session ended. Press any key to close this window."
        read -n 1 -s
        """
        
        do {
            try shellContent.write(toFile: commandFile, atomically: true, encoding: .utf8)
            
            // Make it executable
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/chmod")
            process.arguments = ["+x", commandFile]
            try process.run()
            process.waitUntilExit()
            
            // Open with 'open' command
            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = [commandFile]
            try openProcess.run()
            
            // Clean up after delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                try? FileManager.default.removeItem(atPath: commandFile)
            }
            
        } catch {
            print("Error in final fallback: \(error)")
            // Show alert to user
            DispatchQueue.main.async {
                self.showManualInstructions()
            }
        }
    }
    
    private func showManualInstructions() {
        let alert = NSAlert()
        alert.messageText = "Unable to Open Terminal"
        alert.informativeText = "Could not automatically open Terminal. Please open Terminal manually and run:\n\n\(adbPath) -s \(device.deviceId) shell"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Copy command to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("\(adbPath) -s \(device.deviceId) shell", forType: .string)
        }
    }
    
    func openShellInITerm() {
        // iTerm2 kullanıcıları için alternatif
        let command = "\(adbPath) -s \(device.deviceId) shell"
        
        let script = """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(command)"
                end tell
            end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("Error opening iTerm: \(error)")
                // iTerm yoksa Terminal'i dene
                openShellInTerminal()
            }
        }
    }
    
    func runQuickCommand(_ command: String, completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let adbClient = ADBClient(adbPath: adbPath)
            let result = adbClient.shell(command: command, deviceId: device.deviceId)
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
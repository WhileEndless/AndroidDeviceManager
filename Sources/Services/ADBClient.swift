import Foundation

struct CommandResult {
    let output: String
    let error: String
    let exitCode: Int32
    var isSuccess: Bool { exitCode == 0 }
}

class ADBClient {
    let adbPath: String
    private let processRunner: ProcessRunner
    
    init(adbPath: String? = nil) {
        self.adbPath = adbPath ?? Preferences.shared.adbPath
        self.processRunner = ProcessRunner()
    }
    
    func executeCommand(args: [String], deviceId: String? = nil) -> CommandResult {
        var fullArgs = [String]()
        
        // Add device selection if specified
        if let deviceId = deviceId {
            fullArgs.append(contentsOf: ["-s", deviceId])
        }
        
        fullArgs.append(contentsOf: args)
        
        return processRunner.run(command: adbPath, arguments: fullArgs)
    }
    
    func shell(command: String, deviceId: String? = nil, persistent: Bool = false, timeout: TimeInterval = 5.0) -> CommandResult {
        if persistent, let deviceId = deviceId {
            // Use persistent session
            return ShellSessionManager.shared.executeCommand(
                deviceId: deviceId,
                command: command,
                timeout: timeout
            )
        } else {
            // Use traditional one-shot execution
            return executeCommand(args: ["shell", command], deviceId: deviceId)
        }
    }
    
    func shellAsRoot(command: String, deviceId: String, timeout: TimeInterval = 5.0) -> CommandResult {
        // Always use persistent session for root commands to avoid repeated prompts
        return ShellSessionManager.shared.executeCommand(
            deviceId: deviceId,
            command: command,
            requiresRoot: true,
            timeout: timeout
        )
    }
    
    
    func sendTextToDevice(text: String, deviceId: String) -> CommandResult {
        // Türkçe karakterleri İngilizce karşılıklarıyla değiştir
        let normalizedText = normalizeTurkishCharacters(text)
        
        // Boşlukları %s ile değiştir
        let safeText = normalizedText.replacingOccurrences(of: " ", with: "%s")
        
        // Önce direkt process yöntemi
        let args = ["-s", deviceId, "shell", "input", "text", safeText]
        
        print("Original text: \(text)")
        print("Normalized text: \(normalizedText)")
        print("Sending with args: \(args)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            let result = CommandResult(
                output: output,
                error: error,
                exitCode: process.terminationStatus
            )
            
            print("Direct process result: \(result.isSuccess)")
            
            if result.isSuccess {
                return result
            }
        } catch {
            print("Process error: \(error)")
        }
        
        // Fallback: Shell komutu ile
        let escapedText = safeText
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        
        let shellCommand = "input text '\(escapedText)'"
        let result = shell(command: shellCommand, deviceId: deviceId)
        
        print("Shell command fallback: \(shellCommand)")
        print("Result: \(result.isSuccess), error: \(result.error)")
        
        return result
    }
    
    private func normalizeTurkishCharacters(_ text: String) -> String {
        var normalized = text
        
        // Türkçe karakterleri İngilizce karşılıklarıyla değiştir
        // Küçük harfler
        normalized = normalized.replacingOccurrences(of: "ı", with: "i")
        normalized = normalized.replacingOccurrences(of: "ğ", with: "g")
        normalized = normalized.replacingOccurrences(of: "ü", with: "u")
        normalized = normalized.replacingOccurrences(of: "ş", with: "s")
        normalized = normalized.replacingOccurrences(of: "ö", with: "o")
        normalized = normalized.replacingOccurrences(of: "ç", with: "c")
        
        // Büyük harfler
        normalized = normalized.replacingOccurrences(of: "İ", with: "I")
        normalized = normalized.replacingOccurrences(of: "Ğ", with: "G")
        normalized = normalized.replacingOccurrences(of: "Ü", with: "U")
        normalized = normalized.replacingOccurrences(of: "Ş", with: "S")
        normalized = normalized.replacingOccurrences(of: "Ö", with: "O")
        normalized = normalized.replacingOccurrences(of: "Ç", with: "C")
        
        return normalized
    }
    
    func getDevices() -> [(id: String, status: String)] {
        let result = executeCommand(args: ["devices", "-l"])
        guard result.isSuccess else { return [] }
        
        var devices: [(String, String)] = []
        let lines = result.output.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("List of devices") {
                continue
            }
            
            let components = trimmed.split(separator: " ", maxSplits: 1)
            if components.count >= 2 {
                let deviceId = String(components[0])
                let status = String(components[1])
                if status.contains("device") {
                    devices.append((deviceId, status))
                }
            }
        }
        
        return devices
    }
    
    func getProperty(property: String, deviceId: String, persistent: Bool = true) -> String? {
        let result = shell(command: "getprop \(property)", deviceId: deviceId, persistent: persistent)
        guard result.isSuccess else { return nil }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getProperties(_ properties: [String], deviceId: String) -> [String: String] {
        // Get all properties in a single command
        let propsCommand = properties.map { "echo \"$0:\"; getprop \($0)" }.joined(separator: "; ")
        let result = shell(command: propsCommand, deviceId: deviceId, persistent: true)
        
        var propertyMap: [String: String] = [:]
        guard result.isSuccess else { return propertyMap }
        
        // Parse the output
        let lines = result.output.components(separatedBy: .newlines)
        var currentProperty: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix(":") {
                currentProperty = String(trimmed.dropLast())
            } else if let prop = currentProperty, !trimmed.isEmpty {
                propertyMap[prop] = trimmed
                currentProperty = nil
            }
        }
        
        return propertyMap
    }
    
    func checkRoot(deviceId: String) -> Bool {
        let result = shell(command: "su -c 'whoami'", deviceId: deviceId)
        return result.isSuccess && result.output.contains("root")
    }
    
    func push(localPath: String, remotePath: String, deviceId: String) -> CommandResult {
        return executeCommand(args: ["push", localPath, remotePath], deviceId: deviceId)
    }
    
    func pull(remotePath: String, localPath: String, deviceId: String) -> CommandResult {
        print("[ADBClient] Pulling file:")
        print("[ADBClient]   From: \(remotePath)")
        print("[ADBClient]   To: \(localPath)")
        print("[ADBClient]   Device: \(deviceId)")
        
        let result = executeCommand(args: ["pull", remotePath, localPath], deviceId: deviceId)
        
        print("[ADBClient] Pull result:")
        print("[ADBClient]   Success: \(result.isSuccess)")
        print("[ADBClient]   Output: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
        print("[ADBClient]   Error: \(result.error.trimmingCharacters(in: .whitespacesAndNewlines))")
        print("[ADBClient]   Exit code: \(result.exitCode)")
        
        return result
    }
    
    func forward(localPort: Int, remotePort: Int, deviceId: String) -> CommandResult {
        return executeCommand(
            args: ["forward", "tcp:\(localPort)", "tcp:\(remotePort)"],
            deviceId: deviceId
        )
    }
    
    func removeForward(localPort: Int, deviceId: String) -> CommandResult {
        return executeCommand(
            args: ["forward", "--remove", "tcp:\(localPort)"],
            deviceId: deviceId
        )
    }
    
    func reverse(remotePort: Int, localPort: Int, deviceId: String) -> CommandResult {
        return executeCommand(
            args: ["reverse", "tcp:\(remotePort)", "tcp:\(localPort)"],
            deviceId: deviceId
        )
    }
    
    func removeReverse(remotePort: Int, deviceId: String) -> CommandResult {
        return executeCommand(
            args: ["reverse", "--remove", "tcp:\(remotePort)"],
            deviceId: deviceId
        )
    }
    
    func listForwards(deviceId: String? = nil) -> [(local: String, remote: String)] {
        let result = executeCommand(args: ["forward", "--list"], deviceId: deviceId)
        guard result.isSuccess else { return [] }
        
        var forwards: [(String, String)] = []
        let lines = result.output.split(separator: "\n")
        
        for line in lines {
            let components = line.split(separator: " ")
            if components.count >= 3 {
                let local = String(components[1])
                let remote = String(components[2])
                forwards.append((local, remote))
            }
        }
        
        return forwards
    }
    
    func listReverses(deviceId: String) -> [(device: String, local: String)] {
        let result = executeCommand(args: ["reverse", "--list"], deviceId: deviceId)
        guard result.isSuccess else { return [] }
        
        var reverses: [(String, String)] = []
        let lines = result.output.split(separator: "\n")
        
        for line in lines {
            let components = line.split(separator: " ")
            if components.count >= 3 {
                let device = String(components[1])
                let local = String(components[2])
                reverses.append((device, local))
            }
        }
        
        return reverses
    }
    
    func screencap(outputPath: String, deviceId: String) -> CommandResult {
        let remotePath = "/sdcard/screenshot_temp.png"
        
        // Take screenshot
        let screencapResult = shell(command: "screencap -p \(remotePath)", deviceId: deviceId)
        guard screencapResult.isSuccess else { return screencapResult }
        
        // Pull to local
        let pullResult = pull(remotePath: remotePath, localPath: outputPath, deviceId: deviceId)
        
        // Clean up remote file
        _ = shell(command: "rm \(remotePath)", deviceId: deviceId)
        
        return pullResult
    }
    
    func startLogcat(deviceId: String, packageName: String? = nil) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        
        var args = ["-s", deviceId, "logcat"]
        if let packageName = packageName {
            // Get PID of the package
            let pidResult = shell(command: "pidof \(packageName)", deviceId: deviceId)
            if pidResult.isSuccess, let pid = pidResult.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").first {
                args.append("--pid=\(pid)")
            }
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        return process
    }
    
    func clearLogcat(deviceId: String) -> CommandResult {
        return executeCommand(args: ["logcat", "-c"], deviceId: deviceId)
    }
    
    func listPackages(deviceId: String, includeSystemApps: Bool = true) -> [String] {
        let args = includeSystemApps ? "" : "-3"
        let result = shell(command: "pm list packages \(args)", deviceId: deviceId)
        guard result.isSuccess else { return [] }
        
        return result.output
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("package:") {
                    return String(trimmed.dropFirst("package:".count))
                }
                return nil
            }
            .sorted()
    }
    
    func getPackagePath(packageName: String, deviceId: String) -> [String] {
        let result = shell(command: "pm path \(packageName)", deviceId: deviceId)
        guard result.isSuccess else { return [] }
        
        return result.output
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("package:") {
                    return String(trimmed.dropFirst("package:".count))
                }
                return nil
            }
    }
    
    func getPackageInfo(packageName: String, deviceId: String) -> (appName: String, versionName: String, versionCode: String)? {
        let result = shell(command: "dumpsys package \(packageName) | grep -E 'versionCode|versionName|userId'", deviceId: deviceId)
        guard result.isSuccess else { return nil }
        
        var versionName = ""
        var versionCode = ""
        
        let lines = result.output.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("versionCode=") {
                // Extract versionCode value
                if let range = trimmed.range(of: "versionCode=") {
                    let startIndex = trimmed.index(range.upperBound, offsetBy: 0)
                    let remaining = String(trimmed[startIndex...])
                    let versionCodeValue = remaining.split(separator: " ").first ?? ""
                    versionCode = String(versionCodeValue)
                }
            } else if trimmed.contains("versionName=") {
                // Extract versionName value
                if let range = trimmed.range(of: "versionName=") {
                    let startIndex = trimmed.index(range.upperBound, offsetBy: 0)
                    let remaining = String(trimmed[startIndex...])
                    let versionNameValue = remaining.split(separator: " ").first ?? ""
                    versionName = String(versionNameValue)
                }
            }
        }
        
        // Try to get app label
        let _ = shell(command: "cmd package list packages -f | grep \(packageName)", deviceId: deviceId)
        var appName = packageName
        
        // Try to get the actual app name from dumpsys
        let appInfoResult = shell(command: "dumpsys package \(packageName) | grep -A1 'labelRes'", deviceId: deviceId)
        if appInfoResult.isSuccess && appInfoResult.output.contains("labelRes") {
            // For now, use package name as app name
            // Getting actual app label would require parsing resources which is complex
            appName = packageName.split(separator: ".").last.map(String.init) ?? packageName
        }
        
        return (appName, versionName, versionCode)
    }
    
    func pullFile(remotePath: String, localPath: String, deviceId: String) -> CommandResult {
        return pull(remotePath: remotePath, localPath: localPath, deviceId: deviceId)
    }
}

class ProcessRunner {
    func run(command: String, arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Debug log
        print("[ProcessRunner] Executing command:")
        print("[ProcessRunner]   Path: \(command)")
        print("[ProcessRunner]   Args: \(arguments.joined(separator: " "))")
        print("[ProcessRunner]   Full: \(command) \(arguments.joined(separator: " "))")
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            return CommandResult(
                output: output,
                error: error,
                exitCode: process.terminationStatus
            )
        } catch {
            return CommandResult(
                output: "",
                error: error.localizedDescription,
                exitCode: -1
            )
        }
    }
}
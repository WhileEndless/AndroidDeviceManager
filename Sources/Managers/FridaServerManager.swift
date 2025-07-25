import Foundation

struct FridaServer {
    let path: String
    let name: String
    let version: String?
    let architecture: String
    let size: Int64
    let isRunning: Bool
    let pid: Int32?
    
    var displayName: String {
        if let version = version {
            return "frida-server \(version) (\(architecture))"
        }
        return name
    }
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: size)
    }
}

class FridaServerManager {
    private let device: Device
    private let adbClient: ADBClient
    
    // Common Frida server paths
    private let serverPaths = [
        "/data/local/tmp/frida-server",
        "/data/local/tmp/frida-server-arm",
        "/data/local/tmp/frida-server-arm64",
        "/data/local/tmp/frida-server-x86",
        "/data/local/tmp/frida-server-x86_64",
        "/system/bin/frida-server",
        "/system/xbin/frida-server"
    ]
    
    init(device: Device) {
        self.device = device
        self.adbClient = ADBClient()
    }
    
    // MARK: - Public Methods
    
    func findInstalledServers(completion: @escaping (Result<[FridaServer], Error>) -> Void) {
        print("FridaServerManager: findInstalledServers called for device \(device.deviceId)")
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var servers: [FridaServer] = []
            var processedPaths = Set<String>()
            
            print("FridaServerManager: Starting search...")
            
            // Use traditional adb shell WITHOUT persistent flag first to avoid hanging
            let findCommand = "find /data/local/tmp -name 'frida-server*' -type f 2>/dev/null || echo 'FIND_COMPLETE'"
            print("FridaServerManager: Executing find command: \(findCommand)")
            
            let findResult = adbClient.shell(
                command: findCommand,
                deviceId: device.deviceId,
                persistent: false  // Don't use persistent session initially
            )
            
            print("FridaServerManager: Find result - success: \(findResult.isSuccess), output length: \(findResult.output.count)")
            
            if findResult.isSuccess && !findResult.output.isEmpty {
                let lines = findResult.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                print("FridaServerManager: Found \(lines.count) lines")
                
                for line in lines where !line.isEmpty && line != "FIND_COMPLETE" {
                    print("FridaServerManager: Found path: \(line)")
                    processedPaths.insert(line)
                }
            }
            
            // Also check known paths
            print("FridaServerManager: Checking \(serverPaths.count) known paths")
            for path in serverPaths {
                if !processedPaths.contains(path) {
                    let checkResult = adbClient.shell(
                        command: "test -f \(path) && echo 'EXISTS' || echo 'NOT_FOUND'",
                        deviceId: device.deviceId,
                        persistent: false
                    )
                    
                    if checkResult.isSuccess && checkResult.output.contains("EXISTS") {
                        print("FridaServerManager: Known path exists: \(path)")
                        processedPaths.insert(path)
                    }
                }
            }
            
            print("FridaServerManager: Total paths to check: \(processedPaths.count)")
            
            // Get info for all found paths
            for path in processedPaths {
                print("FridaServerManager: Getting info for: \(path)")
                if let server = self.getServerInfoSimple(path: path) {
                    print("FridaServerManager: Server info retrieved: \(server.displayName)")
                    servers.append(server)
                }
            }
            
            // Get running status for all servers
            print("FridaServerManager: Checking running processes")
            let psResult = adbClient.shell(
                command: "ps -A 2>/dev/null | grep 'frida-server' | grep -v grep || echo 'PS_COMPLETE'",
                deviceId: device.deviceId,
                persistent: false
            )
            
            if psResult.isSuccess {
                print("FridaServerManager: PS output: \(psResult.output.prefix(200))...")
                updateRunningStatus(for: &servers, psOutput: psResult.output)
            }
            
            print("FridaServerManager: Search complete. Found \(servers.count) servers")
            
            DispatchQueue.main.async {
                completion(.success(servers))
            }
        }
    }
    
    func startServer(_ server: FridaServer, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Check if root access is available
            let rootCheck = adbClient.checkRoot(deviceId: device.deviceId)
            if !rootCheck {
                DispatchQueue.main.async {
                    completion(.failure(FridaError.rootRequired))
                }
                return
            }
            
            // Check if any frida server is already running
            let runningServer = findRunningFridaServer()
            if let running = runningServer {
                if running.path == server.path {
                    // Same server is already running
                    DispatchQueue.main.async {
                        completion(.failure(FridaError.alreadyRunning))
                    }
                    return
                } else {
                    // Different server is running, need to stop it first
                    DispatchQueue.main.async {
                        completion(.failure(FridaError.anotherServerRunning(running.displayName)))
                    }
                    return
                }
            }
            
            // Make executable if needed (with root)
            _ = adbClient.shellAsRoot(command: "chmod +x \(server.path)", deviceId: device.deviceId)
            
            // Start frida-server with root (without nohup, let -D handle daemon mode)
            let startCommand = "\(server.path) -D"
            let result = adbClient.shellAsRoot(command: startCommand, deviceId: device.deviceId)
            
            // Give it a moment to start
            Thread.sleep(forTimeInterval: 1.0)
            
            // Check if it's running (with root)
            let checkResult = checkIfServerRunningWithRoot(path: server.path)
            
            DispatchQueue.main.async {
                if checkResult {
                    completion(.success(()))
                } else {
                    let error = result.error.isEmpty ? "Failed to start Frida server" : result.error
                    completion(.failure(FridaError.startFailed(error)))
                }
            }
        }
    }
    
    func stopServer(_ server: FridaServer, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard server.isRunning, let pid = server.pid else {
                DispatchQueue.main.async {
                    completion(.failure(FridaError.notRunning))
                }
                return
            }
            
            // Kill the process (need root if server was started with root)
            let result = adbClient.shellAsRoot(command: "kill -9 \(pid)", deviceId: device.deviceId)
            
            DispatchQueue.main.async {
                if result.isSuccess {
                    completion(.success(()))
                } else {
                    completion(.failure(FridaError.stopFailed(result.error)))
                }
            }
        }
    }
    
    func deleteServer(_ server: FridaServer, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Stop if running
            if server.isRunning {
                let stopResult = adbClient.shell(command: "kill -9 \(server.pid ?? 0)", deviceId: device.deviceId)
                if !stopResult.isSuccess {
                    DispatchQueue.main.async {
                        completion(.failure(FridaError.deleteFailed("Cannot stop running server")))
                    }
                    return
                }
            }
            
            // Delete the file (may need root depending on location)
            var result = adbClient.shell(command: "rm -f \(server.path)", deviceId: device.deviceId)
            
            // If failed, try with root
            if !result.isSuccess {
                result = adbClient.shellAsRoot(command: "rm -f \(server.path)", deviceId: device.deviceId)
            }
            
            DispatchQueue.main.async {
                if result.isSuccess {
                    completion(.success(()))
                } else {
                    completion(.failure(FridaError.deleteFailed(result.error)))
                }
            }
        }
    }
    
    func uploadServer(from localPath: String, to remotePath: String = "/data/local/tmp/frida-server", completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Push the file
            let result = adbClient.push(localPath: localPath, remotePath: remotePath, deviceId: device.deviceId)
            
            if result.isSuccess {
                // Make it executable (try with root if needed)
                var chmodResult = adbClient.shell(command: "chmod +x \(remotePath)", deviceId: device.deviceId)
                if !chmodResult.isSuccess {
                    chmodResult = adbClient.shellAsRoot(command: "chmod +x \(remotePath)", deviceId: device.deviceId)
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(FridaError.uploadFailed(result.error)))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getServerInfo(path: String) -> FridaServer? {
        // Get file info
        let command = "ls -la \(path) 2>/dev/null"
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: command,
            requiresRoot: device.isRooted,
            timeout: 2.0
        )
        
        guard result.isSuccess && !result.output.contains("No such file") else {
            return nil
        }
        
        return parseServerFromLsOutput(result.output.trimmingCharacters(in: .whitespacesAndNewlines), path: path)
    }
    
    private func getServerInfoSimple(path: String) -> FridaServer? {
        // Get file info using adbClient WITHOUT persistent session to avoid hanging
        let result = adbClient.shell(
            command: "ls -la \(path) 2>/dev/null",
            deviceId: device.deviceId,
            persistent: false
        )
        
        guard result.isSuccess && !result.output.contains("No such file") else {
            print("FridaServerManager: Failed to get info for \(path)")
            return nil
        }
        
        return parseServerFromLsOutput(result.output.trimmingCharacters(in: .whitespacesAndNewlines), path: path)
    }
    
    private func checkServerAtPathOptimized(_ path: String, useRoot: Bool = false) -> FridaServer? {
        // Get all info in one command
        let command = """
        ls -la \(path) 2>/dev/null && \
        file \(path) 2>/dev/null | head -1
        """
        
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: command,
            requiresRoot: useRoot
        )
        
        guard result.isSuccess && !result.output.contains("No such file") else {
            return nil
        }
        
        let lines = result.output.split(separator: "\n")
        guard lines.count >= 1 else { return nil }
        
        // Parse ls output
        let lsOutput = String(lines[0])
        guard let server = parseServerFromLsOutput(lsOutput, path: path) else {
            return nil
        }
        
        // Get architecture from file command if available
        if lines.count > 1 {
            let fileOutput = String(lines[1])
            let arch = detectArchitectureFromFileOutput(fileOutput, name: server.name)
            return FridaServer(
                path: server.path,
                name: server.name,
                version: server.version,
                architecture: arch,
                size: server.size,
                isRunning: server.isRunning,
                pid: server.pid
            )
        }
        
        return server
    }
    
    private func parseServerFromLsOutput(_ lsOutput: String, path: String) -> FridaServer? {
        let components = lsOutput.split(separator: " ").compactMap { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard components.count >= 5 else { return nil }
        
        // Get file size
        let size = Int64(components[4]) ?? 0
        
        // Get file name
        let name = URL(fileURLWithPath: path).lastPathComponent
        
        // Try to get version
        let version = extractVersion(from: name)
        
        // Detect architecture from name
        let arch = detectArchitectureFromName(name)
        
        return FridaServer(
            path: path,
            name: name,
            version: version,
            architecture: arch,
            size: size,
            isRunning: false,  // Will be updated later
            pid: nil
        )
    }
    
    private func updateRunningStatus(for servers: inout [FridaServer], psOutput: String) {
        let lines = psOutput.split(separator: "\n")
        
        for i in 0..<servers.count {
            let server = servers[i]
            let filename = URL(fileURLWithPath: server.path).lastPathComponent
            
            for line in lines {
                if line.contains(filename) {
                    let components = line.split(separator: " ").compactMap { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    if components.count >= 2, let pid = Int32(components[1]) {
                        servers[i] = FridaServer(
                            path: server.path,
                            name: server.name,
                            version: server.version,
                            architecture: server.architecture,
                            size: server.size,
                            isRunning: true,
                            pid: pid
                        )
                        break
                    }
                }
            }
        }
    }
    
    private func detectArchitectureFromName(_ name: String) -> String {
        if name.contains("arm64") || name.contains("aarch64") { return "arm64" }
        if name.contains("arm") { return "arm" }
        if name.contains("x86_64") || name.contains("x64") { return "x86_64" }
        if name.contains("x86") { return "x86" }
        return "unknown"
    }
    
    private func detectArchitectureFromFileOutput(_ output: String, name: String) -> String {
        let lowercaseOutput = output.lowercased()
        if lowercaseOutput.contains("aarch64") || lowercaseOutput.contains("arm64") { return "arm64" }
        if lowercaseOutput.contains("arm") { return "arm" }
        if lowercaseOutput.contains("x86-64") || lowercaseOutput.contains("x86_64") { return "x86_64" }
        if lowercaseOutput.contains("x86") || lowercaseOutput.contains("i386") { return "x86" }
        
        // Fallback to name detection
        return detectArchitectureFromName(name)
    }
    
    private func checkServerAtPath(_ path: String, useRoot: Bool = false) -> FridaServer? {
        // Check if file exists and get info
        let lsCommand = "ls -la \(path) 2>/dev/null"
        let lsResult = useRoot ? adbClient.shellAsRoot(command: lsCommand, deviceId: device.deviceId) : adbClient.shell(command: lsCommand, deviceId: device.deviceId)
        
        guard lsResult.isSuccess && !lsResult.output.contains("No such file") && !lsResult.output.contains("Permission denied") else {
            return nil
        }
        
        // Parse file info
        let components = lsResult.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard components.count >= 5 else { return nil }
        
        // Get file size
        let size = Int64(components[4]) ?? 0
        
        // Get file name
        let name = URL(fileURLWithPath: path).lastPathComponent
        
        // Try to get version
        let version = extractVersion(from: name)
        
        // Detect architecture
        let arch = detectArchitecture(from: name, path: path, useRoot: useRoot)
        
        // Check if running
        let (isRunning, pid) = checkIfServerRunningWithPID(path: path)
        
        return FridaServer(
            path: path,
            name: name,
            version: version,
            architecture: arch,
            size: size,
            isRunning: isRunning,
            pid: pid
        )
    }
    
    private func extractVersion(from name: String) -> String? {
        // Try to extract version from filename like frida-server-16.1.4-android-arm64
        let pattern = #"(\d+\.\d+\.\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
            return String(name[Range(match.range(at: 1), in: name)!])
        }
        return nil
    }
    
    private func detectArchitecture(from name: String, path: String, useRoot: Bool = false) -> String {
        // Check filename first
        if name.contains("arm64") || name.contains("aarch64") { return "arm64" }
        if name.contains("arm") { return "arm" }
        if name.contains("x86_64") || name.contains("x64") { return "x86_64" }
        if name.contains("x86") { return "x86" }
        
        // If not in filename, check file info
        let fileCommand = "file \(path) 2>/dev/null"
        let fileResult = useRoot ? adbClient.shellAsRoot(command: fileCommand, deviceId: device.deviceId) : adbClient.shell(command: fileCommand, deviceId: device.deviceId)
        if fileResult.isSuccess {
            let output = fileResult.output.lowercased()
            if output.contains("aarch64") || output.contains("arm64") { return "arm64" }
            if output.contains("arm") { return "arm" }
            if output.contains("x86-64") || output.contains("x86_64") { return "x86_64" }
            if output.contains("x86") || output.contains("i386") { return "x86" }
        }
        
        return "unknown"
    }
    
    private func checkIfServerRunning(path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: "ps -A 2>/dev/null | grep '\(filename)' | grep -v grep || true",
            requiresRoot: device.isRooted
        )
        
        return result.isSuccess && !result.output.isEmpty
    }
    
    private func checkIfServerRunningWithRoot(path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: "ps -A | grep '\(filename)' | grep -v grep || true",
            requiresRoot: true
        )
        return result.isSuccess && !result.output.isEmpty
    }
    
    private func checkIfServerRunningWithPID(path: String) -> (Bool, Int32?) {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: "ps -A 2>/dev/null | grep '\(filename)' | grep -v grep || true",
            requiresRoot: device.isRooted
        )
        
        if result.isSuccess && !result.output.isEmpty {
            // Parse PID from ps output
            let lines = result.output.split(separator: "\n")
            for line in lines {
                let components = line.split(separator: " ").compactMap { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if components.count >= 2, let pid = Int32(components[1]) {
                    return (true, pid)
                }
            }
        }
        
        return (false, nil)
    }
    
    private func findRunningFridaServer() -> FridaServer? {
        // Look for any running frida-server process and get its info
        let result = ShellSessionManager.shared.executeCommand(
            deviceId: device.deviceId,
            command: "ps -A | grep 'frida-server' | grep -v grep || true",
            requiresRoot: device.isRooted
        )
        
        if result.isSuccess && !result.output.isEmpty {
            let lines = result.output.split(separator: "\n")
            for line in lines {
                let components = line.split(separator: " ").compactMap { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                
                // Try to extract the path from the process line
                for component in components {
                    if component.contains("frida-server") {
                        // Found a running frida server, check if we know about it
                        for path in serverPaths {
                            if component.contains(path) || path.contains(component) {
                                if let server = checkServerAtPathOptimized(path, useRoot: device.isRooted) {
                                    return server
                                }
                            }
                        }
                        
                        // Check common paths
                        let commonPaths = [
                            "/data/local/tmp/\(component)",
                            component
                        ]
                        
                        for path in commonPaths {
                            if let server = checkServerAtPathOptimized(path, useRoot: device.isRooted) {
                                return server
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    func stopAllFridaServers(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Kill all frida-server processes
            let result = ShellSessionManager.shared.executeCommand(
                deviceId: device.deviceId,
                command: "pkill -f frida-server",
                requiresRoot: true
            )
            
            DispatchQueue.main.async {
                if result.isSuccess || result.output.isEmpty {
                    completion(.success(()))
                } else {
                    completion(.failure(FridaError.stopFailed("Failed to stop all Frida servers")))
                }
            }
        }
    }
}

enum FridaError: LocalizedError {
    case alreadyRunning
    case notRunning
    case rootRequired
    case anotherServerRunning(String)
    case startFailed(String)
    case stopFailed(String)
    case deleteFailed(String)
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "This Frida server is already running"
        case .notRunning:
            return "Frida server is not running"
        case .rootRequired:
            return "Root access is required to run Frida server"
        case .anotherServerRunning(let name):
            return "Another Frida server is already running: \(name). Please stop it first."
        case .startFailed(let error):
            return "Failed to start Frida server: \(error)"
        case .stopFailed(let error):
            return "Failed to stop Frida server: \(error)"
        case .deleteFailed(let error):
            return "Failed to delete Frida server: \(error)"
        case .uploadFailed(let error):
            return "Failed to upload Frida server: \(error)"
        }
    }
}
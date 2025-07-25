import Foundation

class ShellSession {
    private let deviceId: String
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    private(set) var isRoot = false
    private(set) var isAlive = false
    private let requestRoot: Bool
    
    private let commandQueue = DispatchQueue(label: "shellSession.\(UUID().uuidString)")
    private var outputBuffer = ""
    private let outputLock = NSLock()
    
    // Prompt detection
    private let promptPatterns = [
        "shell@",      // Normal shell prompt
        "root@",       // Root shell prompt  
        ":/ $",        // Common Android shell prompt
        ":/ #",        // Common Android root prompt
        "$ ",          // Generic shell
        "# "           // Generic root
    ]
    
    private let adbPath: String
    
    init(deviceId: String, adbPath: String = "/usr/local/bin/adb", requestRoot: Bool = true) {
        self.deviceId = deviceId
        self.adbPath = adbPath
        self.requestRoot = requestRoot
    }
    
    deinit {
        close()
    }
    
    // MARK: - Session Management
    
    func start() throws {
        guard !isAlive else { return }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: adbPath)
        process?.arguments = ["-s", deviceId, "shell"]
        
        inputPipe = Pipe()
        outputPipe = Pipe()
        errorPipe = Pipe()
        
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Monitor process termination
        process?.terminationHandler = { [weak self] _ in
            self?.handleProcessTermination()
        }
        
        // Setup output monitoring
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                self?.handleOutput(output)
            }
        }
        
        try process?.run()
        isAlive = true
        
        // Wait for initial prompt
        Thread.sleep(forTimeInterval: 0.1)
        
        // Clear any initial output
        clearOutputBuffer()
        
        // Check and escalate to root if requested
        if requestRoot {
            checkAndEscalateRoot()
        }
    }
    
    func close() {
        isAlive = false
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }
    
    private func handleProcessTermination() {
        isAlive = false
        isRoot = false
    }
    
    // MARK: - Command Execution
    
    func executeCommand(_ command: String, timeout: TimeInterval = 5.0) -> CommandResult {
        return commandQueue.sync {
            // Check if session is alive, restart if needed
            if !isAlive {
                do {
                    try start()
                } catch {
                    return CommandResult(output: "", error: "Failed to restart shell session: \(error)", exitCode: -1)
                }
            }
            
            // Clear buffer before command
            clearOutputBuffer()
            
            // Send command
            guard let data = "\(command)\n".data(using: .utf8) else {
                return CommandResult(output: "", error: "Failed to encode command", exitCode: -1)
            }
            
            inputPipe?.fileHandleForWriting.write(data)
            
            // Wait for output with timeout
            let deadline = Date().addingTimeInterval(timeout)
            var output = ""
            
            while Date() < deadline {
                outputLock.lock()
                output = outputBuffer
                outputLock.unlock()
                
                // Check if we have a prompt indicating command completion
                if containsPrompt(output) || output.contains("__EOF__") {
                    break
                }
                
                Thread.sleep(forTimeInterval: 0.01) // Reduced from 50ms to 10ms
            }
            
            // Clean output
            let cleanedOutput = cleanOutput(output, command: command)
            
            return CommandResult(output: cleanedOutput, error: "", exitCode: 0)
        }
    }
    
    // MARK: - Root Management
    
    private func checkAndEscalateRoot() {
        // Quick root check without multiple attempts
        let result = executeCommand("su -c 'echo ROOT_OK'", timeout: 1.0)
        if result.output.contains("ROOT_OK") {
            // We have root, escalate to su shell
            _ = executeCommand("su", timeout: 0.5)
            isRoot = true
        }
    }
    
    // MARK: - Output Handling
    
    private func handleOutput(_ output: String) {
        outputLock.lock()
        outputBuffer.append(output)
        outputLock.unlock()
    }
    
    private func clearOutputBuffer() {
        outputLock.lock()
        outputBuffer = ""
        outputLock.unlock()
    }
    
    private func containsPrompt(_ output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        guard let lastLine = lines.last else { return false }
        
        for pattern in promptPatterns {
            if lastLine.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func cleanOutput(_ output: String, command: String) -> String {
        var lines = output.components(separatedBy: .newlines)
        
        // Remove empty lines
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Remove command echo (first line if it matches)
        if let first = lines.first, first.contains(command) {
            lines.removeFirst()
        }
        
        // Remove prompt line (last line if it contains prompt)
        if let last = lines.last {
            for pattern in promptPatterns {
                if last.contains(pattern) {
                    lines.removeLast()
                    break
                }
            }
        }
        
        // Remove EOF marker if present
        lines = lines.filter { $0 != "__EOF__" }
        
        return lines.joined(separator: "\n")
    }
}


import Foundation
import Cocoa

// Log level types
enum LogLevel: String, CaseIterable {
    case verbose = "V"
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"
    case fatal = "F"
    
    var color: NSColor {
        switch self {
        case .verbose: return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)  // Gray
        case .debug: return NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)   // Blue
        case .info: return NSColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)    // Green
        case .warning: return NSColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0) // Orange
        case .error: return NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0)   // Red
        case .fatal: return NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1.0)   // Purple
        }
    }
    
    var backgroundColor: NSColor {
        switch self {
        case .verbose: return NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        case .debug: return NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        case .info: return NSColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
        case .warning: return NSColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        case .error: return NSColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
        case .fatal: return NSColor(red: 1.0, green: 0.9, blue: 1.0, alpha: 1.0)
        }
    }
}

struct LogEntry {
    let timestamp: String
    let pid: String
    let tid: String
    let level: LogLevel
    let tag: String
    let message: String
    let rawLine: String
    
    var formattedLine: NSAttributedString {
        let attributed = NSMutableAttributedString()
        
        // Level badge
        let levelStr = NSAttributedString(
            string: " \(level.rawValue) ",
            attributes: [
                .foregroundColor: NSColor.white,
                .backgroundColor: level.color,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            ]
        )
        attributed.append(levelStr)
        
        // Timestamp
        let timestampStr = NSAttributedString(
            string: " \(timestamp) ",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            ]
        )
        attributed.append(timestampStr)
        
        // PID/TID
        let pidStr = NSAttributedString(
            string: "[\(pid)/\(tid)] ",
            attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            ]
        )
        attributed.append(pidStr)
        
        // Tag
        let tagStr = NSAttributedString(
            string: "\(tag): ",
            attributes: [
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            ]
        )
        attributed.append(tagStr)
        
        // Message
        let messageStr = NSAttributedString(
            string: message,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            ]
        )
        attributed.append(messageStr)
        
        return attributed
    }
}

protocol LogcatManagerDelegate: AnyObject {
    func logcatManager(_ manager: LogcatManager, didReceiveEntry entry: LogEntry)
    func logcatManager(_ manager: LogcatManager, didUpdatePID oldPID: String?, newPID: String?)
    func logcatManager(_ manager: LogcatManager, didEncounterError error: Error)
}

class LogcatManager {
    private let device: Device
    private let adbClient: ADBClient
    private var logcatProcess: Process?
    private var pidMonitorTimer: Timer?
    private var currentPID: String?
    private var packageName: String?
    private var enabledLevels: Set<LogLevel> = Set(LogLevel.allCases)
    private var searchFilter: String?
    
    // Performance optimization
    private let processQueue = DispatchQueue(label: "com.androiddevicemanager.logcat", qos: .userInitiated)
    private let parseQueue = DispatchQueue(label: "com.androiddevicemanager.logcat.parse", qos: .userInitiated, attributes: .concurrent)
    
    // Log count management
    private var logCount = 0
    private var maxLogCount = 10000
    private let logCountLock = NSLock()
    
    // Package filter buffering
    private var isWaitingForPID = false
    private var bufferedLogs: [LogEntry] = []
    private let bufferLock = NSLock()
    private let maxBufferSize = 1000
    
    weak var delegate: LogcatManagerDelegate?
    
    // Regex for parsing logcat lines
    // Format: MM-DD HH:MM:SS.mmm PID TID LEVEL TAG: Message
    private let logRegex = try! NSRegularExpression(
        pattern: #"^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(\d+)\s+(\d+)\s+([VDIWEF])\s+(.+?):\s*(.*)$"#,
        options: []
    )
    
    // Alternative simpler format without TAG
    private let simpleLogRegex = try! NSRegularExpression(
        pattern: #"^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+([VDIWEF])/(.+?)\s*\(\s*(\d+)\):\s*(.*)$"#,
        options: []
    )
    
    init(device: Device) {
        self.device = device
        self.adbClient = ADBClient()
    }
    
    // MARK: - Public Methods
    
    func startLogcat(packageName: String? = nil) {
        stopLogcat()
        
        self.packageName = packageName
        
        if let package = packageName {
            // Start buffering until PID is found
            bufferLock.lock()
            isWaitingForPID = true
            bufferedLogs.removeAll()
            bufferLock.unlock()
            
            // Start PID monitoring for package
            startPIDMonitoring(for: package)
        } else {
            bufferLock.lock()
            isWaitingForPID = false
            bufferedLogs.removeAll()
            bufferLock.unlock()
        }
        
        startLogcatProcess()
    }
    
    func stopLogcat() {
        processQueue.async { [weak self] in
            self?.logcatProcess?.terminate()
            self?.logcatProcess = nil
        }
        pidMonitorTimer?.invalidate()
        pidMonitorTimer = nil
        currentPID = nil
        
        // Reset log count
        logCountLock.lock()
        logCount = 0
        logCountLock.unlock()
        
        // Clear buffer
        bufferLock.lock()
        isWaitingForPID = false
        bufferedLogs.removeAll()
        bufferLock.unlock()
    }
    
    func clearLogs() {
        _ = adbClient.clearLogcat(deviceId: device.deviceId)
        
        // Reset log count
        logCountLock.lock()
        logCount = 0
        logCountLock.unlock()
    }
    
    func setLevelFilter(_ levels: Set<LogLevel>) {
        self.enabledLevels = levels
    }
    
    func setSearchFilter(_ filter: String?) {
        self.searchFilter = filter?.isEmpty == true ? nil : filter
    }
    
    func setMaxLogCount(_ count: Int) {
        self.maxLogCount = max(100, min(count, 50000)) // Between 100 and 50000
        
        // Reset count if we're over the new limit
        logCountLock.lock()
        if logCount > maxLogCount {
            logCount = 0
            // Notify delegate to clear logs
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.logcatManager(self, didEncounterError: NSError(domain: "LogcatManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Log limit reached. Logs have been cleared."]))
            }
        }
        logCountLock.unlock()
    }
    
    func exportLogs(to url: URL, entries: [LogEntry]) throws {
        let content = entries.map { $0.rawLine }.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private Methods
    
    private func startLogcatProcess() {
        processQueue.async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.adbClient.adbPath)
            process.arguments = ["-s", self.device.deviceId, "logcat", "-v", "threadtime"]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var buffer = ""
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.count > 0 {
                    if let text = String(data: data, encoding: .utf8) {
                        buffer += text
                        
                        // Process complete lines
                        let lines = buffer.components(separatedBy: "\n")
                        
                        // Batch process lines for better performance
                        var linesToProcess = [String]()
                        for i in 0..<lines.count - 1 {
                            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !line.isEmpty {
                                linesToProcess.append(line)
                            }
                        }
                        
                        // Process in chunks to avoid blocking
                        if !linesToProcess.isEmpty {
                            let chunkSize = 50
                            for i in stride(from: 0, to: linesToProcess.count, by: chunkSize) {
                                let end = min(i + chunkSize, linesToProcess.count)
                                let chunk = Array(linesToProcess[i..<end])
                                self?.batchProcessLines(chunk)
                            }
                        }
                        
                        // Keep the last incomplete line in buffer
                        buffer = lines.last ?? ""
                    }
                }
            }
        
            // Capture stderr for error handling
            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.count > 0 {
                    if let errorText = String(data: data, encoding: .utf8), !errorText.isEmpty {
                        DispatchQueue.main.async {
                            self?.delegate?.logcatManager(self!, didEncounterError: NSError(domain: "LogcatManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorText]))
                        }
                    }
                }
            }
            
            // Monitor process termination
            process.terminationHandler = { [weak self] process in
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        self?.delegate?.logcatManager(self!, didEncounterError: NSError(domain: "LogcatManager", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Logcat process terminated with status: \(process.terminationStatus)"]))
                    }
                }
            }
            
            do {
                try process.run()
                self.logcatProcess = process
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.logcatManager(self, didEncounterError: error)
                }
            }
        }
    }
    
    private func batchProcessLines(_ lines: [String]) {
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            var entriesToAdd = [LogEntry]()
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else { continue }
                
                // Try to parse the log line
                if let entry = self.parseLogLine(trimmedLine) {
                    // Check if we're waiting for PID
                    self.bufferLock.lock()
                    let waitingForPID = self.isWaitingForPID
                    self.bufferLock.unlock()
                    
                    if waitingForPID && self.packageName != nil {
                        // Buffer logs until PID is found
                        self.bufferLock.lock()
                        if self.bufferedLogs.count < self.maxBufferSize {
                            self.bufferedLogs.append(entry)
                        }
                        self.bufferLock.unlock()
                        continue
                    }
                    
                    // Filter by PID if monitoring a package
                    if self.packageName != nil {
                        // We have a package filter
                        if let pid = self.currentPID {
                            // PID found, filter by it
                            if entry.pid != pid {
                                continue
                            }
                        } else {
                            // No PID found for package, skip all logs
                            continue
                        }
                    }
                    
                    // Filter by log level
                    if !self.enabledLevels.contains(entry.level) {
                        continue
                    }
                    
                    // Filter by search text
                    if let filter = self.searchFilter, !entry.rawLine.localizedCaseInsensitiveContains(filter) {
                        continue
                    }
                    
                    entriesToAdd.append(entry)
                }
            }
            
            if !entriesToAdd.isEmpty {
                // Update log count (no limit check - viewer will handle rotation)
                self.logCountLock.lock()
                self.logCount += entriesToAdd.count
                self.logCountLock.unlock()
                
                // Send all entries to delegate on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    for entry in entriesToAdd {
                        self.delegate?.logcatManager(self, didReceiveEntry: entry)
                    }
                }
            }
        }
    }
    
    private func startBatchTimer() {
        // Not needed with new implementation
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Try standard format first
        if let match = logRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            func getString(at index: Int) -> String? {
                guard let range = Range(match.range(at: index), in: line) else { return nil }
                return String(line[range])
            }
            
            guard let timestamp = getString(at: 1),
                  let pidStr = getString(at: 2),
                  let tidStr = getString(at: 3),
                  let levelStr = getString(at: 4),
                  let tag = getString(at: 5),
                  let message = getString(at: 6),
                  let level = LogLevel(rawValue: levelStr) else {
                return nil
            }
            
            return LogEntry(
                timestamp: timestamp,
                pid: pidStr,
                tid: tidStr,
                level: level,
                tag: tag,
                message: message,
                rawLine: line
            )
        }
        
        // Try simple format
        if let match = simpleLogRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            func getString(at index: Int) -> String? {
                guard let range = Range(match.range(at: index), in: line) else { return nil }
                return String(line[range])
            }
            
            guard let timestamp = getString(at: 1),
                  let levelStr = getString(at: 2),
                  let tag = getString(at: 3),
                  let pidStr = getString(at: 4),
                  let message = getString(at: 5),
                  let level = LogLevel(rawValue: levelStr) else {
                return nil
            }
            
            return LogEntry(
                timestamp: timestamp,
                pid: pidStr,
                tid: pidStr, // Use PID as TID in simple format
                level: level,
                tag: tag,
                message: message,
                rawLine: line
            )
        }
        
        return nil
    }
    
    private func startPIDMonitoring(for packageName: String) {
        updatePID(for: packageName)
        
        DispatchQueue.main.async { [weak self] in
            self?.pidMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.updatePID(for: packageName)
            }
        }
    }
    
    private func updatePID(for packageName: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.adbClient.shell(command: "pidof \(packageName)", deviceId: self.device.deviceId)
            
            let newPID = result.isSuccess ? result.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").first : nil
            
            if newPID != self.currentPID {
                let oldPID = self.currentPID
                self.currentPID = newPID
                
                // Debug log
                if let pid = newPID {
                    print("LogcatManager: Updated PID for \(packageName): \(pid)")
                    
                    // Process buffered logs if we were waiting for PID
                    self.bufferLock.lock()
                    if self.isWaitingForPID {
                        self.isWaitingForPID = false
                        let logsToProcess = self.bufferedLogs
                        self.bufferedLogs.removeAll()
                        self.bufferLock.unlock()
                        
                        // Send buffered logs that match the PID
                        var matchingLogs: [LogEntry] = []
                        for entry in logsToProcess {
                            if entry.pid == pid {
                                // Apply other filters
                                if self.enabledLevels.contains(entry.level) {
                                    if let filter = self.searchFilter, !entry.rawLine.localizedCaseInsensitiveContains(filter) {
                                        continue
                                    }
                                    matchingLogs.append(entry)
                                }
                            }
                        }
                        
                        // Send matching logs to delegate
                        if !matchingLogs.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                for entry in matchingLogs {
                                    self.delegate?.logcatManager(self, didReceiveEntry: entry)
                                }
                            }
                        }
                    } else {
                        self.bufferLock.unlock()
                    }
                } else {
                    print("LogcatManager: No PID found for \(packageName)")
                    self.bufferLock.lock()
                    self.isWaitingForPID = true
                    self.bufferLock.unlock()
                }
                
                DispatchQueue.main.async {
                    self.delegate?.logcatManager(self, didUpdatePID: oldPID, newPID: newPID)
                }
            }
        }
    }
}
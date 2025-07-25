import Foundation

enum ForwardType: String, Codable {
    case forward = "Forward"    // Local to Device
    case reverse = "Reverse"    // Device to Local
}

struct PortForward: Codable {
    let id: UUID
    let deviceId: String
    let localPort: Int
    let remotePort: Int
    let description: String
    let type: ForwardType
    var isActive: Bool
    let createdAt: Date
    
    init(deviceId: String, localPort: Int, remotePort: Int, type: ForwardType = .forward, description: String = "") {
        self.id = UUID()
        self.deviceId = deviceId
        self.localPort = localPort
        self.remotePort = remotePort
        self.type = type
        self.description = description
        self.isActive = false
        self.createdAt = Date()
    }
}

class PortForwardManager {
    private let device: Device
    private let adbClient: ADBClient
    private var activeForwards: [PortForward] = []
    
    // UserDefaults key for saved forwards
    private let savedForwardsKey = "savedPortForwards"
    
    init(device: Device) {
        self.device = device
        self.adbClient = ADBClient()
        loadSavedForwards()
        refreshActiveForwards()
    }
    
    // MARK: - Public Methods
    
    func createForward(localPort: Int, remotePort: Int, type: ForwardType = .forward, description: String = "") -> Result<PortForward, Error> {
        // Validate ports
        guard isValidPort(localPort) && isValidPort(remotePort) else {
            return .failure(PortForwardError.invalidPort)
        }
        
        // Check if port is already in use
        if type == .forward && isLocalPortInUse(localPort, type: type) {
            return .failure(PortForwardError.portInUse(localPort))
        } else if type == .reverse && isRemotePortInUse(remotePort, type: type) {
            return .failure(PortForwardError.portInUse(remotePort))
        }
        
        // Create the forward or reverse
        let result: CommandResult
        if type == .forward {
            result = adbClient.forward(localPort: localPort, remotePort: remotePort, deviceId: device.deviceId)
        } else {
            result = adbClient.reverse(remotePort: remotePort, localPort: localPort, deviceId: device.deviceId)
        }
        
        if result.isSuccess {
            var forward = PortForward(deviceId: device.deviceId, localPort: localPort, remotePort: remotePort, type: type, description: description)
            forward.isActive = true
            activeForwards.append(forward)
            saveForwards()
            return .success(forward)
        } else {
            return .failure(PortForwardError.adbError(result.error))
        }
    }
    
    func removeForward(_ forward: PortForward) -> Result<Void, Error> {
        let result: CommandResult
        if forward.type == .forward {
            result = adbClient.removeForward(localPort: forward.localPort, deviceId: device.deviceId)
        } else {
            result = adbClient.removeReverse(remotePort: forward.remotePort, deviceId: device.deviceId)
        }
        
        if result.isSuccess {
            activeForwards.removeAll { $0.id == forward.id }
            saveForwards()
            return .success(())
        } else {
            return .failure(PortForwardError.adbError(result.error))
        }
    }
    
    func removeAllForwards() -> Result<Void, Error> {
        var hasError = false
        var lastError = ""
        
        for forward in activeForwards {
            let result = adbClient.removeForward(localPort: forward.localPort, deviceId: device.deviceId)
            if !result.isSuccess {
                hasError = true
                lastError = result.error
            }
        }
        
        if hasError {
            return .failure(PortForwardError.adbError(lastError))
        } else {
            activeForwards.removeAll()
            saveForwards()
            return .success(())
        }
    }
    
    func getActiveForwards() -> [PortForward] {
        return activeForwards
    }
    
    func getSavedForwards() -> [PortForward] {
        guard let data = UserDefaults.standard.data(forKey: savedForwardsKey),
              let forwards = try? JSONDecoder().decode([PortForward].self, from: data) else {
            return []
        }
        
        return forwards.filter { $0.deviceId == device.deviceId }
    }
    
    func refreshActiveForwards() {
        var allForwards: [PortForward] = []
        
        // Get regular forwards
        let forwards = adbClient.listForwards(deviceId: device.deviceId)
        for (local, remote) in forwards {
            guard let localPort = parsePort(from: local),
                  let remotePort = parsePort(from: remote) else {
                continue
            }
            
            let saved = getSavedForwards().first { $0.localPort == localPort && $0.remotePort == remotePort && $0.type == .forward }
            
            var forward = PortForward(
                deviceId: device.deviceId,
                localPort: localPort,
                remotePort: remotePort,
                type: .forward,
                description: saved?.description ?? ""
            )
            forward.isActive = true
            allForwards.append(forward)
        }
        
        // Get reverse forwards
        let reverses = adbClient.listReverses(deviceId: device.deviceId)
        for (devicePort, localPort) in reverses {
            guard let remotePort = parsePort(from: devicePort),
                  let localPort = parsePort(from: localPort) else {
                continue
            }
            
            let saved = getSavedForwards().first { $0.localPort == localPort && $0.remotePort == remotePort && $0.type == .reverse }
            
            var reverse = PortForward(
                deviceId: device.deviceId,
                localPort: localPort,
                remotePort: remotePort,
                type: .reverse,
                description: saved?.description ?? ""
            )
            reverse.isActive = true
            allForwards.append(reverse)
        }
        
        activeForwards = allForwards
    }
    
    // MARK: - Private Methods
    
    private func isValidPort(_ port: Int) -> Bool {
        return port > 0 && port <= 65535
    }
    
    private func isLocalPortInUse(_ port: Int, type: ForwardType) -> Bool {
        return activeForwards.contains { $0.localPort == port && $0.type == type }
    }
    
    private func isRemotePortInUse(_ port: Int, type: ForwardType) -> Bool {
        return activeForwards.contains { $0.remotePort == port && $0.type == type }
    }
    
    private func parsePort(from string: String) -> Int? {
        // Format is usually "tcp:XXXX"
        let components = string.split(separator: ":")
        if components.count == 2, let port = Int(components[1]) {
            return port
        }
        return nil
    }
    
    private func loadSavedForwards() {
        // Saved forwards are loaded through getSavedForwards()
    }
    
    private func saveForwards() {
        var allForwards = getSavedForwardsForAllDevices()
        
        // Remove old forwards for this device
        allForwards.removeAll { $0.deviceId == device.deviceId }
        
        // Add current forwards
        allForwards.append(contentsOf: activeForwards)
        
        if let data = try? JSONEncoder().encode(allForwards) {
            UserDefaults.standard.set(data, forKey: savedForwardsKey)
        }
    }
    
    private func getSavedForwardsForAllDevices() -> [PortForward] {
        guard let data = UserDefaults.standard.data(forKey: savedForwardsKey),
              let forwards = try? JSONDecoder().decode([PortForward].self, from: data) else {
            return []
        }
        return forwards
    }
}

enum PortForwardError: LocalizedError {
    case invalidPort
    case portInUse(Int)
    case adbError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Invalid port number. Port must be between 1 and 65535."
        case .portInUse(let port):
            return "Port \(port) is already in use."
        case .adbError(let error):
            return "ADB error: \(error)"
        }
    }
}
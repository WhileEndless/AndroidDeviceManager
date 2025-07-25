//
//  FileManagerWindow.swift
//  AndroidDeviceManager
//
//  Created by ADB File Manager on 2025-01-25.
//

import Cocoa

class FileManagerWindow: NSWindowController {
    
    private let device: Device
    private let adbClient: ADBClient
    
    init(device: Device, adbClient: ADBClient) {
        self.device = device
        self.adbClient = adbClient
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "File Manager - \(device.modelName)"
        window.minSize = NSSize(width: 600, height: 400)
        
        super.init(window: window)
        
        // Set up content view controller
        let contentVC = FileListViewController(device: device, adbClient: adbClient)
        window.contentViewController = contentVC
        
        // Center window
        window.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
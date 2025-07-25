//
//  FileItem.swift
//  AndroidDeviceManager
//
//  Created by ADB File Manager on 2025-01-25.
//

import Foundation

struct FileItem {
    let permissions: String
    let linkCount: Int
    let owner: String
    let group: String
    let sizeString: String  // Human readable: "4.0K", "12M"
    let dateString: String  // "2025-01-25"
    let timeString: String  // "15:30"
    let name: String
    let linkTarget: String? // For symlinks
    
    // Parent path for full path construction
    let parentPath: String
    
    // Computed properties
    var isDirectory: Bool {
        return permissions.first == "d"
    }
    
    var isSymlink: Bool {
        return permissions.first == "l"
    }
    
    var isFile: Bool {
        return permissions.first == "-"
    }
    
    var fullPath: String {
        if parentPath.hasSuffix("/") {
            return parentPath + name
        } else {
            return parentPath + "/" + name
        }
    }
    
    var icon: String {
        if isDirectory {
            // Special directories
            switch name {
            case "Android": return "🤖"
            case "Download", "Downloads": return "⬇️"
            case "DCIM", "Pictures": return "📷"
            case "Music": return "🎵"
            case "Movies", "Videos": return "🎬"
            case "Documents": return "📑"
            default: return "📁"
            }
        } else if isSymlink {
            return "🔗"
        } else {
            // File extensions
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "apk": return "📦"
            case "jpg", "jpeg", "png", "gif": return "🖼️"
            case "mp4", "avi", "mkv": return "🎬"
            case "mp3", "wav", "ogg": return "🎵"
            case "txt", "log": return "📄"
            case "pdf": return "📕"
            case "zip", "rar", "7z": return "🗜️"
            case "db", "sqlite": return "🗄️"
            default: return "📄"
            }
        }
    }
    
    var displayDate: String {
        return "\(dateString) \(timeString)"
    }
    
    // Helper for sorting
    var sizeInBytes: Int64 {
        // Parse size string to bytes for sorting
        let numericPart = sizeString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let value = Double(numericPart) else { return 0 }
        
        if sizeString.contains("K") {
            return Int64(value * 1024)
        } else if sizeString.contains("M") {
            return Int64(value * 1024 * 1024)
        } else if sizeString.contains("G") {
            return Int64(value * 1024 * 1024 * 1024)
        } else {
            return Int64(value)
        }
    }
}

// MARK: - Equatable
extension FileItem: Equatable {
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.fullPath == rhs.fullPath
    }
}

// MARK: - Hashable
extension FileItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(fullPath)
    }
}
//
//  LSParser.swift
//  AndroidDeviceManager
//
//  Created by ADB File Manager on 2025-01-25.
//

import Foundation

class LSParser {
    
    static func parse(output: String, currentPath: String) -> [FileItem] {
        var items: [FileItem] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            // Skip empty lines, "total" line, and EOF marker
            if line.isEmpty || line.hasPrefix("total") || line == "__EOF__" {
                continue
            }
            
            if let item = parseLine(line, parentPath: currentPath) {
                items.append(item)
            }
        }
        
        // Sort: directories first, then by name
        items.sort { item1, item2 in
            if item1.isDirectory != item2.isDirectory {
                return item1.isDirectory
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
        
        return items
    }
    
    private static func parseLine(_ line: String, parentPath: String) -> FileItem? {
        // Split by whitespace, keeping track of position
        let components = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        
        // Need at least 8 components for a valid ls -lah line
        guard components.count >= 8 else { return nil }
        
        // Extract basic fields
        let permissions = components[0]
        let linkCount = Int(components[1]) ?? 0
        let owner = components[2]
        let group = components[3]
        let size = components[4]
        let date = components[5]
        let time = components[6]
        
        // Handle filename and optional symlink
        var name: String
        var linkTarget: String? = nil
        
        // Join remaining components for the filename
        let nameStartIndex = 7
        let remainingComponents = Array(components[nameStartIndex...])
        let remainingString = remainingComponents.joined(separator: " ")
        
        // Check for symlink arrow " -> "
        if permissions.first == "l", let arrowRange = remainingString.range(of: " -> ") {
            name = String(remainingString[..<arrowRange.lowerBound])
            linkTarget = String(remainingString[arrowRange.upperBound...])
        } else {
            name = remainingString
        }
        
        // Skip "." and ".." entries
        if name == "." || name == ".." {
            return nil
        }
        
        return FileItem(
            permissions: permissions,
            linkCount: linkCount,
            owner: owner,
            group: group,
            sizeString: size,
            dateString: date,
            timeString: time,
            name: name,
            linkTarget: linkTarget,
            parentPath: parentPath
        )
    }
    
    // Helper method to parse error messages
    static func parseError(_ output: String) -> String? {
        if output.contains("Permission denied") {
            return "Permission denied. Root access may be required."
        } else if output.contains("No such file or directory") {
            return "Directory not found."
        } else if output.contains("Not a directory") {
            return "Path is not a directory."
        } else if !output.isEmpty {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
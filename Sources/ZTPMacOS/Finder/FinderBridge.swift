import Foundation

// MARK: - FinderBridge

public struct FinderBridge: Sendable {

    // MARK: - Models

    public struct Result: Sendable {
        public let success: Bool
        public let message: String
    }

    public struct FileInfo: Codable, Sendable {
        public let name: String
        public let path: String
        public let isDirectory: Bool
        public let size: Int64
        public let modified: String  // ISO 8601
        public let type: String      // file extension or "directory"
    }

    // MARK: - Public API

    /// Reveals the item at the given path in Finder.
    public static func reveal(path: String) throws -> Result {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FinderError.pathNotFound(expandedPath)
        }

        let escaped = expandedPath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            tell application "Finder"
                reveal POSIX file "\(escaped)"
                activate
            end tell
            """
        let output = shellOutput("osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")
        _ = output
        return Result(success: true, message: "Revealed \(expandedPath) in Finder")
    }

    /// Opens a folder in Finder using the `open` command.
    public static func openFolder(path: String) throws -> Result {
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDir) else {
            throw FinderError.pathNotFound(expandedPath)
        }
        guard isDir.boolValue else {
            throw FinderError.notADirectory(expandedPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [expandedPath]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return Result(success: true, message: "Opened folder \(expandedPath)")
        } else {
            return Result(success: false, message: "Failed to open folder \(expandedPath)")
        }
    }

    /// Lists the contents of a directory with file metadata.
    public static func list(path: String) throws -> [FileInfo] {
        let expandedPath = (path as NSString).expandingTildeInPath
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue else {
            throw FinderError.notADirectory(expandedPath)
        }

        let contents = try fm.contentsOfDirectory(atPath: expandedPath)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var results: [FileInfo] = []
        for item in contents {
            let fullPath = (expandedPath as NSString).appendingPathComponent(item)
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath) else { continue }

            let fileType = attrs[.type] as? FileAttributeType
            let isDirectory = fileType == .typeDirectory
            let size = (attrs[.size] as? Int64) ?? 0
            let modDate = (attrs[.modificationDate] as? Date) ?? Date()
            let modified = formatter.string(from: modDate)
            let ext = isDirectory ? "directory" : (fullPath as NSString).pathExtension

            results.append(FileInfo(
                name: item,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                modified: modified,
                type: ext.isEmpty ? "file" : ext
            ))
        }

        return results
    }
}

// MARK: - Errors

public enum FinderError: Error, Sendable {
    case pathNotFound(String)
    case notADirectory(String)
}

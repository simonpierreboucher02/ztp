import Foundation

// MARK: - FileOperations

public struct FileOperations: Sendable {

    // MARK: - Models

    public struct FileResult: Sendable {
        public let success: Bool
        public let message: String
        public let path: String?
    }

    // MARK: - Public API

    /// Reads the contents of a file as a UTF-8 string.
    public static func read(path: String) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FileOpError.fileNotFound(expandedPath)
        }
        return try String(contentsOfFile: expandedPath, encoding: .utf8)
    }

    /// Writes content to a file. Requires `confirmed == true`.
    public static func write(path: String, content: String, confirmed: Bool) throws -> FileResult {
        guard confirmed else {
            throw FileOpError.notConfirmed("write to \(path)")
        }
        let expandedPath = (path as NSString).expandingTildeInPath

        // Ensure parent directory exists
        let parent = (expandedPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
        return FileResult(success: true, message: "Written to \(expandedPath)", path: expandedPath)
    }

    /// Copies a file from one path to another.
    public static func copy(from: String, to: String) throws -> FileResult {
        let src = (from as NSString).expandingTildeInPath
        let dst = (to as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: src) else {
            throw FileOpError.fileNotFound(src)
        }

        // Ensure parent directory of destination exists
        let parent = (dst as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Remove destination if it already exists
        if FileManager.default.fileExists(atPath: dst) {
            try FileManager.default.removeItem(atPath: dst)
        }

        try FileManager.default.copyItem(atPath: src, toPath: dst)
        return FileResult(success: true, message: "Copied \(src) to \(dst)", path: dst)
    }

    /// Moves a file from one path to another. Requires `confirmed == true`.
    public static func move(from: String, to: String, confirmed: Bool) throws -> FileResult {
        guard confirmed else {
            throw FileOpError.notConfirmed("move \(from) to \(to)")
        }
        let src = (from as NSString).expandingTildeInPath
        let dst = (to as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: src) else {
            throw FileOpError.fileNotFound(src)
        }

        // Ensure parent directory of destination exists
        let parent = (dst as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Remove destination if it already exists
        if FileManager.default.fileExists(atPath: dst) {
            try FileManager.default.removeItem(atPath: dst)
        }

        try FileManager.default.moveItem(atPath: src, toPath: dst)
        return FileResult(success: true, message: "Moved \(src) to \(dst)", path: dst)
    }

    /// Deletes a file or directory. Requires `confirmed == true`.
    public static func delete(path: String, confirmed: Bool) throws -> FileResult {
        guard confirmed else {
            throw FileOpError.notConfirmed("delete \(path)")
        }
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw FileOpError.fileNotFound(expandedPath)
        }
        try FileManager.default.removeItem(atPath: expandedPath)
        return FileResult(success: true, message: "Deleted \(expandedPath)", path: expandedPath)
    }

    /// Returns true if a file or directory exists at the given path.
    public static func exists(path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    /// Returns file info for a single path (reuses FinderBridge.FileInfo format).
    public static func info(path: String) throws -> FinderBridge.FileInfo {
        let expandedPath = (path as NSString).expandingTildeInPath
        let fm = FileManager.default
        guard fm.fileExists(atPath: expandedPath) else {
            throw FileOpError.fileNotFound(expandedPath)
        }

        let attrs = try fm.attributesOfItem(atPath: expandedPath)
        let fileType = attrs[.type] as? FileAttributeType
        let isDirectory = fileType == .typeDirectory
        let size = (attrs[.size] as? Int64) ?? 0
        let modDate = (attrs[.modificationDate] as? Date) ?? Date()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let modified = formatter.string(from: modDate)

        let name = (expandedPath as NSString).lastPathComponent
        let ext = isDirectory ? "directory" : (expandedPath as NSString).pathExtension

        return FinderBridge.FileInfo(
            name: name,
            path: expandedPath,
            isDirectory: isDirectory,
            size: size,
            modified: modified,
            type: ext.isEmpty ? "file" : ext
        )
    }
}

// MARK: - Errors

public enum FileOpError: Error, Sendable {
    case fileNotFound(String)
    case notConfirmed(String)
}

import Foundation

// MARK: - Models

public struct FileEntry: Sendable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let isSymlink: Bool
    public let size: Int64
    public let modified: String
    public let ext: String
    public let depth: Int

    public init(name: String, path: String, isDirectory: Bool, isSymlink: Bool, size: Int64, modified: String, ext: String, depth: Int = 0) {
        self.name = name; self.path = path; self.isDirectory = isDirectory; self.isSymlink = isSymlink
        self.size = size; self.modified = modified; self.ext = ext; self.depth = depth
    }
}

public struct SearchMatch: Sendable {
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let lineMatches: [LineMatch]
    public init(path: String, name: String, isDirectory: Bool, size: Int64, lineMatches: [LineMatch] = []) {
        self.path = path; self.name = name; self.isDirectory = isDirectory; self.size = size; self.lineMatches = lineMatches
    }
}

public struct LineMatch: Sendable {
    public let line: Int
    public let text: String
}

public struct OpResult: Sendable {
    public let success: Bool
    public let message: String
    public let path: String?
}

public enum FilesError: Error, Sendable, CustomStringConvertible {
    case notFound(String)
    case notADirectory(String)
    case notConfirmed(String)
    case alreadyExists(String)
    case ioFailed(String)
    public var description: String {
        switch self {
        case .notFound(let p): return "Path not found: \(p)"
        case .notADirectory(let p): return "Not a directory: \(p)"
        case .notConfirmed(let a): return "Operation requires --confirm: \(a)"
        case .alreadyExists(let p): return "Already exists: \(p)"
        case .ioFailed(let m): return "I/O failed: \(m)"
        }
    }
}

// MARK: - FilesEngine

/// Filesystem navigation, search, mutation and (de)compression. Pure
/// Foundation + `/usr/bin/ditto` for zip; no shell.
public enum FilesEngine {

    private static var fm: FileManager { .default }

    private static func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f.string(from: date)
    }

    private static func attrs(_ path: String) -> (isDir: Bool, isLink: Bool, size: Int64, modified: Date) {
        let isLink = (try? fm.destinationOfSymbolicLink(atPath: path)) != nil
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: path, isDirectory: &isDir)
        let a = (try? fm.attributesOfItem(atPath: path)) ?? [:]
        let size = (a[.size] as? Int64) ?? 0
        let mod = (a[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)
        return (isDir.boolValue, isLink, size, mod)
    }

    // MARK: List

    public enum SortKey: String, Sendable { case name, size, date }

    public static func list(path: String, includeHidden: Bool, sort: SortKey) throws -> [FileEntry] {
        let dir = expand(path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir, isDirectory: &isDir) else { throw FilesError.notFound(dir) }
        guard isDir.boolValue else { throw FilesError.notADirectory(dir) }

        let names = try fm.contentsOfDirectory(atPath: dir)
        var entries: [FileEntry] = []
        for name in names {
            if !includeHidden && name.hasPrefix(".") { continue }
            let full = (dir as NSString).appendingPathComponent(name)
            let a = attrs(full)
            let ext = a.isDir ? "directory" : (full as NSString).pathExtension
            entries.append(FileEntry(name: name, path: full, isDirectory: a.isDir, isSymlink: a.isLink,
                                     size: a.size, modified: iso(a.modified), ext: ext.isEmpty ? "file" : ext))
        }
        return sortEntries(entries, by: sort)
    }

    private static func sortEntries(_ entries: [FileEntry], by sort: SortKey) -> [FileEntry] {
        switch sort {
        case .name: return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: return entries.sorted { $0.size > $1.size }
        case .date: return entries.sorted { $0.modified > $1.modified }
        }
    }

    // MARK: Tree

    public static func tree(path: String, maxDepth: Int, maxEntries: Int, includeHidden: Bool) throws -> [FileEntry] {
        let root = expand(path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { throw FilesError.notADirectory(root) }

        var out: [FileEntry] = []
        func walk(_ dir: String, _ depth: Int) {
            if depth > maxDepth || out.count >= maxEntries { return }
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for name in names.sorted() {
                if out.count >= maxEntries { return }
                if !includeHidden && name.hasPrefix(".") { continue }
                let full = (dir as NSString).appendingPathComponent(name)
                let a = attrs(full)
                let ext = a.isDir ? "directory" : (full as NSString).pathExtension
                out.append(FileEntry(name: name, path: full, isDirectory: a.isDir, isSymlink: a.isLink,
                                     size: a.size, modified: iso(a.modified), ext: ext.isEmpty ? "file" : ext, depth: depth))
                if a.isDir && !a.isLink { walk(full, depth + 1) }
            }
        }
        walk(root, 0)
        return out
    }

    // MARK: Search

    public static func search(
        path: String, query: String, regex: Bool, searchContent: Bool,
        ext: String?, maxResults: Int, includeHidden: Bool
    ) throws -> [SearchMatch] {
        let root = expand(path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { throw FilesError.notADirectory(root) }

        let wantedExt = ext?.lowercased().replacingOccurrences(of: ".", with: "")
        let nameMatcher: (String) -> Bool
        if regex, let re = try? NSRegularExpression(pattern: query, options: [.caseInsensitive]) {
            nameMatcher = { s in re.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)) != nil }
        } else {
            let q = query.lowercased()
            nameMatcher = { $0.lowercased().contains(q) }
        }

        var matches: [SearchMatch] = []
        let enumerator = fm.enumerator(atPath: root)
        while let rel = enumerator?.nextObject() as? String {
            if matches.count >= maxResults { break }
            let name = (rel as NSString).lastPathComponent
            if !includeHidden && rel.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { continue }
            let full = (root as NSString).appendingPathComponent(rel)
            let a = attrs(full)
            if let wantedExt, !a.isDir, (full as NSString).pathExtension.lowercased() != wantedExt { continue }

            if searchContent && !a.isDir {
                if let lineMatches = contentMatches(file: full, query: query, regex: regex), !lineMatches.isEmpty {
                    matches.append(SearchMatch(path: full, name: name, isDirectory: false, size: a.size, lineMatches: lineMatches))
                }
            } else if nameMatcher(name) {
                matches.append(SearchMatch(path: full, name: name, isDirectory: a.isDir, size: a.size))
            }
        }
        return matches
    }

    private static func contentMatches(file: String, query: String, regex: Bool) -> [LineMatch]? {
        guard let data = fm.contents(atPath: file), data.count < 5_000_000,
              let text = String(data: data, encoding: .utf8) else { return nil }
        var out: [LineMatch] = []
        let re = regex ? try? NSRegularExpression(pattern: query, options: [.caseInsensitive]) : nil
        let q = query.lowercased()
        var lineNo = 0
        for line in text.components(separatedBy: "\n") {
            lineNo += 1
            let hit: Bool
            if let re { hit = re.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil }
            else { hit = line.lowercased().contains(q) }
            if hit {
                out.append(LineMatch(line: lineNo, text: String(line.prefix(300))))
                if out.count >= 20 { break }
            }
        }
        return out
    }

    // MARK: Info

    public static func info(path: String) throws -> FileEntry {
        let full = expand(path)
        guard fm.fileExists(atPath: full) else { throw FilesError.notFound(full) }
        let a = attrs(full)
        let ext = a.isDir ? "directory" : (full as NSString).pathExtension
        return FileEntry(name: (full as NSString).lastPathComponent, path: full, isDirectory: a.isDir,
                         isSymlink: a.isLink, size: a.size, modified: iso(a.modified), ext: ext.isEmpty ? "file" : ext)
    }

    // MARK: Mutations

    public static func copy(from: String, to: String) throws -> OpResult {
        let src = expand(from), dst = expand(to)
        guard fm.fileExists(atPath: src) else { throw FilesError.notFound(src) }
        try ensureParent(dst)
        if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
        try fm.copyItem(atPath: src, toPath: dst)
        return OpResult(success: true, message: "Copied to \(dst)", path: dst)
    }

    public static func move(from: String, to: String, confirmed: Bool) throws -> OpResult {
        guard confirmed else { throw FilesError.notConfirmed("move \(from) → \(to)") }
        let src = expand(from), dst = expand(to)
        guard fm.fileExists(atPath: src) else { throw FilesError.notFound(src) }
        try ensureParent(dst)
        if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
        try fm.moveItem(atPath: src, toPath: dst)
        return OpResult(success: true, message: "Moved to \(dst)", path: dst)
    }

    public static func rename(path: String, newName: String, confirmed: Bool) throws -> OpResult {
        guard confirmed else { throw FilesError.notConfirmed("rename \(path)") }
        let src = expand(path)
        guard fm.fileExists(atPath: src) else { throw FilesError.notFound(src) }
        let parent = (src as NSString).deletingLastPathComponent
        let dst = (parent as NSString).appendingPathComponent(newName)
        if fm.fileExists(atPath: dst) { throw FilesError.alreadyExists(dst) }
        try fm.moveItem(atPath: src, toPath: dst)
        return OpResult(success: true, message: "Renamed to \(newName)", path: dst)
    }

    public static func mkdir(path: String) throws -> OpResult {
        let dir = expand(path)
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return OpResult(success: true, message: "Created directory \(dir)", path: dir)
    }

    /// Delete to Trash by default (recoverable); `permanent` removes outright.
    public static func delete(path: String, confirmed: Bool, permanent: Bool) throws -> OpResult {
        guard confirmed else { throw FilesError.notConfirmed("delete \(path)") }
        let full = expand(path)
        guard fm.fileExists(atPath: full) else { throw FilesError.notFound(full) }
        if permanent {
            try fm.removeItem(atPath: full)
            return OpResult(success: true, message: "Permanently deleted \(full)", path: full)
        } else {
            try fm.trashItem(at: URL(fileURLWithPath: full), resultingItemURL: nil)
            return OpResult(success: true, message: "Moved to Trash: \(full)", path: full)
        }
    }

    // MARK: Compression (ditto, no shell)

    public static func compress(path: String, output: String) throws -> OpResult {
        let src = expand(path), dst = expand(output)
        guard fm.fileExists(atPath: src) else { throw FilesError.notFound(src) }
        try ensureParent(dst)
        if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
        try runDitto(["-c", "-k", "--sequesterRsrc", "--keepParent", src, dst])
        let size = (try? fm.attributesOfItem(atPath: dst))?[.size] as? Int64 ?? 0
        return OpResult(success: true, message: "Compressed to \(dst) (\(size) bytes)", path: dst)
    }

    public static func extract(input: String, to dir: String, confirmed: Bool) throws -> OpResult {
        guard confirmed else { throw FilesError.notConfirmed("extract \(input)") }
        let zip = expand(input), dest = expand(dir)
        guard fm.fileExists(atPath: zip) else { throw FilesError.notFound(zip) }
        try fm.createDirectory(atPath: dest, withIntermediateDirectories: true)
        try runDitto(["-x", "-k", zip, dest])
        return OpResult(success: true, message: "Extracted to \(dest)", path: dest)
    }

    private static func runDitto(_ args: [String]) throws {
        let process = Process()
        let err = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = args
        process.standardError = err
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "ditto failed"
            throw FilesError.ioFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func ensureParent(_ path: String) throws {
        let parent = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
    }
}

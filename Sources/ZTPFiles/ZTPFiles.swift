import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTPFilesTool

/// Filesystem navigation, search, mutation and (de)compression.
public struct ZTPFilesTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-files",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "list", "tree", "search", "info", "copy", "move", "rename",
            "mkdir", "delete", "compress", "extract",
        ],
        permissions: ["filesystem": true]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified."))
        }
        let start = ContinuousClock.now
        do {
            switch command {
            case "list":     return try runList(input, start)
            case "tree":     return try runTree(input, start)
            case "search":   return try runSearch(input, start)
            case "info":     return try runInfo(input, start)
            case "copy":     return try runCopy(input, start)
            case "move":     return try runMove(input, start)
            case "rename":   return try runRename(input, start)
            case "mkdir":    return try runMkdir(input, start)
            case "delete":   return try runDelete(input, start)
            case "compress": return try runCompress(input, start)
            case "extract":  return try runExtract(input, start)
            default:
                return .failure(tool: manifest.name, error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)"))
            }
        } catch {
            return .failure(tool: manifest.name, durationMs: ems(start), error: ToolErrorInfo(code: "EXECUTION_FAILED", message: "\(error)"))
        }
    }

    private func entryJSON(_ e: FileEntry, withDepth: Bool = false) -> JSONValue {
        var obj: [String: JSONValue] = [
            "name": .string(e.name), "path": .string(e.path), "is_directory": .bool(e.isDirectory),
            "is_symlink": .bool(e.isSymlink), "size": .int(Int(e.size)), "modified": .string(e.modified), "type": .string(e.ext),
        ]
        if withDepth { obj["depth"] = .int(e.depth) }
        return .object(obj)
    }

    private func runList(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        let sort = FilesEngine.SortKey(rawValue: input.string(for: "sort") ?? "name") ?? .name
        let entries = try FilesEngine.list(path: path, includeHidden: input.bool(for: "all") ?? false, sort: sort)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("list"), "path": .string(path),
            "entries": .array(entries.map { entryJSON($0) }), "count": .int(entries.count),
        ])
    }

    private func runTree(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        let entries = try FilesEngine.tree(path: path, maxDepth: input.int(for: "depth") ?? 3,
                                           maxEntries: input.int(for: "max") ?? 2000, includeHidden: input.bool(for: "all") ?? false)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("tree"), "path": .string(path),
            "entries": .array(entries.map { entryJSON($0, withDepth: true) }), "count": .int(entries.count),
        ])
    }

    private func runSearch(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        guard let query = input.string(for: "query") else { return missing("query") }
        let matches = try FilesEngine.search(
            path: path, query: query, regex: input.bool(for: "regex") ?? false,
            searchContent: input.bool(for: "content") ?? false, ext: input.string(for: "ext"),
            maxResults: input.int(for: "max") ?? 200, includeHidden: input.bool(for: "all") ?? false)
        let values: [JSONValue] = matches.map { m in
            var obj: [String: JSONValue] = [
                "path": .string(m.path), "name": .string(m.name), "is_directory": .bool(m.isDirectory), "size": .int(Int(m.size)),
            ]
            if !m.lineMatches.isEmpty {
                obj["matches"] = .array(m.lineMatches.map { .object(["line": .int($0.line), "text": .string($0.text)]) })
            }
            return .object(obj)
        }
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("search"), "path": .string(path), "query": .string(query),
            "results": .array(values), "count": .int(matches.count),
        ])
    }

    private func runInfo(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        let e = try FilesEngine.info(path: path)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("info"), "name": .string(e.name), "path": .string(e.path),
            "is_directory": .bool(e.isDirectory), "is_symlink": .bool(e.isSymlink),
            "size": .int(Int(e.size)), "modified": .string(e.modified), "type": .string(e.ext),
        ])
    }

    private func runCopy(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let from = input.string(for: "from") else { return missing("from") }
        guard let to = input.string(for: "to") else { return missing("to") }
        return opResult(try FilesEngine.copy(from: from, to: to), "copy", start)
    }

    private func runMove(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let from = input.string(for: "from") else { return missing("from") }
        guard let to = input.string(for: "to") else { return missing("to") }
        return opResult(try FilesEngine.move(from: from, to: to, confirmed: input.bool(for: "confirmed") ?? false), "move", start)
    }

    private func runRename(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        guard let name = input.string(for: "name") else { return missing("name") }
        return opResult(try FilesEngine.rename(path: path, newName: name, confirmed: input.bool(for: "confirmed") ?? false), "rename", start)
    }

    private func runMkdir(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        return opResult(try FilesEngine.mkdir(path: path), "mkdir", start)
    }

    private func runDelete(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        return opResult(try FilesEngine.delete(path: path, confirmed: input.bool(for: "confirmed") ?? false,
                                               permanent: input.bool(for: "permanent") ?? false), "delete", start)
    }

    private func runCompress(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else { return missing("path") }
        guard let output = input.string(for: "output") else { return missing("output") }
        return opResult(try FilesEngine.compress(path: path, output: output), "compress", start)
    }

    private func runExtract(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let input2 = input.string(for: "input") else { return missing("input") }
        guard let to = input.string(for: "to") else { return missing("to") }
        return opResult(try FilesEngine.extract(input: input2, to: to, confirmed: input.bool(for: "confirmed") ?? false), "extract", start)
    }

    // MARK: helpers

    private func opResult(_ r: OpResult, _ command: String, _ start: ContinuousClock.Instant) -> ToolResult {
        var data: [String: JSONValue] = [
            "command": .string(command), "success": .bool(r.success), "message": .string(r.message),
        ]
        if let p = r.path { data["path"] = .string(p) }
        return .success(tool: manifest.name, durationMs: ems(start), data: data)
    }

    private func missing(_ field: String) -> ToolResult {
        .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_\(field.uppercased())", message: "Missing '\(field)'."))
    }

    private func ems(_ start: ContinuousClock.Instant) -> Int64 {
        let e = start.duration(to: .now)
        return e.components.seconds * 1000 + e.components.attoseconds / 1_000_000_000_000_000
    }
}

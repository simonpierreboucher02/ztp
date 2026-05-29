import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTPNotesTool

/// Read and write Apple Notes: list, read, create structured notes, append,
/// and delete. Backed by AppleScript via the macOS automation layer.
public struct ZTPNotesTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-notes",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: ["list", "read", "create", "append", "delete", "folders"],
        permissions: ["applescript": true]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified."))
        }
        let start = ContinuousClock.now
        do {
            switch command {
            case "list":    return try runList(input, start)
            case "read":    return try runRead(input, start)
            case "create":  return try runCreate(input, start)
            case "append":  return try runAppend(input, start)
            case "delete":  return try runDelete(input, start)
            case "folders": return try runFolders(start)
            default:
                return .failure(tool: manifest.name, error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)"))
            }
        } catch {
            return .failure(tool: manifest.name, durationMs: ems(start), error: ToolErrorInfo(code: "EXECUTION_FAILED", message: "\(error)"))
        }
    }

    private func runList(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        let items = try NotesBridge.list(folder: input.string(for: "folder"), limit: input.int(for: "limit") ?? 50)
        let values: [JSONValue] = items.map { .object([
            "name": .string($0.name), "folder": .string($0.folder), "modified": .string($0.modified),
        ]) }
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("list"), "notes": .array(values), "count": .int(items.count),
        ])
    }

    private func runRead(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let name = input.string(for: "name") ?? input.string(for: "title") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_NAME", message: "No note name/title."))
        }
        let note = try NotesBridge.read(name: name)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("read"), "name": .string(note.name), "folder": .string(note.folder),
            "text": .string(note.plainText), "html": .string(note.bodyHTML), "char_count": .int(note.plainText.count),
        ])
    }

    private func runCreate(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let title = input.string(for: "title") ?? input.string(for: "name") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_TITLE", message: "No title."))
        }
        let body = input.string(for: "body") ?? ""
        let r = try NotesBridge.create(title: title, body: body, folder: input.string(for: "folder"))
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("create"), "success": .bool(r.success), "message": .string(r.message), "title": .string(title),
        ])
    }

    private func runAppend(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let name = input.string(for: "name") ?? input.string(for: "title") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_NAME", message: "No note name."))
        }
        guard let body = input.string(for: "body") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_BODY", message: "No body to append."))
        }
        let r = try NotesBridge.append(name: name, body: body)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("append"), "success": .bool(r.success), "message": .string(r.message),
        ])
    }

    private func runDelete(_ input: ToolInput, _ start: ContinuousClock.Instant) throws -> ToolResult {
        guard let name = input.string(for: "name") ?? input.string(for: "title") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_NAME", message: "No note name."))
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let r = try NotesBridge.delete(name: name, confirmed: confirmed)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("delete"), "success": .bool(r.success), "message": .string(r.message),
        ])
    }

    private func runFolders(_ start: ContinuousClock.Instant) throws -> ToolResult {
        let folders = try NotesBridge.folders()
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("folders"), "folders": .array(folders.map { .string($0) }), "count": .int(folders.count),
        ])
    }

    private func ems(_ start: ContinuousClock.Instant) -> Int64 {
        let e = start.duration(to: .now)
        return e.components.seconds * 1000 + e.components.attoseconds / 1_000_000_000_000_000
    }
}

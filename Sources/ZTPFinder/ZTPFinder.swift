import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTPFinderTool

/// Advanced Finder control via AppleScript.
public struct ZTPFinderTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-finder",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "selection", "reveal", "open", "new-window", "set-view",
            "info", "trash", "empty-trash", "eject",
        ],
        permissions: ["applescript": true, "filesystem": true]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified."))
        }
        let start = ContinuousClock.now
        let confirmed = input.bool(for: "confirmed") ?? false
        do {
            switch command {
            case "selection":
                let paths = try FinderControl.selection()
                return .success(tool: manifest.name, durationMs: ems(start), data: [
                    "command": .string("selection"), "items": .array(paths.map { .string($0) }), "count": .int(paths.count),
                ])
            case "reveal":
                guard let path = input.string(for: "path") else { return missing("path") }
                return res(try FinderControl.reveal(path: path), "reveal", start)
            case "open":
                guard let path = input.string(for: "path") else { return missing("path") }
                return res(try FinderControl.open(path: path), "open", start)
            case "new-window":
                return res(try FinderControl.newWindow(path: input.string(for: "path")), "new-window", start)
            case "set-view":
                guard let view = input.string(for: "view") else { return missing("view") }
                return res(try FinderControl.setView(view, path: input.string(for: "path")), "set-view", start)
            case "info":
                guard let path = input.string(for: "path") else { return missing("path") }
                let r = try FinderControl.info(path: path)
                return .success(tool: manifest.name, durationMs: ems(start), data: [
                    "command": .string("info"), "success": .bool(r.success), "message": .string(r.message),
                    "kind": .string(r.detail ?? ""),
                ])
            case "trash":
                guard let path = input.string(for: "path") else { return missing("path") }
                return res(try FinderControl.trash(path: path, confirmed: confirmed), "trash", start)
            case "empty-trash":
                return res(try FinderControl.emptyTrash(confirmed: confirmed), "empty-trash", start)
            case "eject":
                guard let name = input.string(for: "name") else { return missing("name") }
                return res(try FinderControl.eject(name: name, confirmed: confirmed), "eject", start)
            default:
                return .failure(tool: manifest.name, error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)"))
            }
        } catch {
            return .failure(tool: manifest.name, durationMs: ems(start), error: ToolErrorInfo(code: "EXECUTION_FAILED", message: "\(error)"))
        }
    }

    private func res(_ r: FinderResult, _ command: String, _ start: ContinuousClock.Instant) -> ToolResult {
        .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string(command), "success": .bool(r.success), "message": .string(r.message),
        ])
    }

    private func missing(_ field: String) -> ToolResult {
        .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_\(field.uppercased())", message: "Missing '\(field)'."))
    }

    private func ems(_ start: ContinuousClock.Instant) -> Int64 {
        let e = start.duration(to: .now)
        return e.components.seconds * 1000 + e.components.attoseconds / 1_000_000_000_000_000
    }
}

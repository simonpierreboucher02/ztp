import Foundation

public struct ToolResult: Codable, Sendable {
    public let ok: Bool
    public let tool: String
    public let durationMs: Int64?
    public let data: [String: JSONValue]?
    public let error: ToolErrorInfo?

    public init(
        ok: Bool,
        tool: String,
        durationMs: Int64? = nil,
        data: [String: JSONValue]? = nil,
        error: ToolErrorInfo? = nil
    ) {
        self.ok = ok
        self.tool = tool
        self.durationMs = durationMs
        self.data = data
        self.error = error
    }

    public static func success(
        tool: String,
        durationMs: Int64,
        data: [String: JSONValue] = [:]
    ) -> ToolResult {
        ToolResult(ok: true, tool: tool, durationMs: durationMs, data: data)
    }

    public static func failure(
        tool: String,
        durationMs: Int64? = nil,
        error: ToolErrorInfo
    ) -> ToolResult {
        ToolResult(ok: false, tool: tool, durationMs: durationMs, error: error)
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case tool
        case durationMs = "duration_ms"
        case data
        case error
    }
}

public struct ToolErrorInfo: Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

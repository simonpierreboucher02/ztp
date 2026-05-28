import Foundation

public struct ZTPConfig: Codable, Sendable {
    public let version: String
    public let toolPaths: [String]
    public let workspacePath: String

    public init(
        version: String = "1.0.0",
        toolPaths: [String] = ["~/.ztp/tools", "/usr/local/lib/ztp", "/opt/homebrew/lib/ztp"],
        workspacePath: String = "~/.ztp/workspaces"
    ) {
        self.version = version
        self.toolPaths = toolPaths
        self.workspacePath = workspacePath
    }

    enum CodingKeys: String, CodingKey {
        case version
        case toolPaths = "tool_paths"
        case workspacePath = "workspace_path"
    }
}

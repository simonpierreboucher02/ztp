import Foundation

public protocol ZTPTool: Sendable {
    var manifest: ToolManifest { get }

    func execute(
        input: ToolInput,
        context: ToolContext
    ) async throws -> ToolResult
}

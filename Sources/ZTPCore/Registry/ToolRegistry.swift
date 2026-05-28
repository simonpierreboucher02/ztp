import Foundation
import ZTPProtocols

public struct ToolRegistry: Sendable {
    private var tools: [String: any ZTPTool] = [:]

    public init() {}

    public mutating func register(tool: any ZTPTool) {
        tools[tool.manifest.name] = tool
    }

    public func get(name: String) -> (any ZTPTool)? {
        tools[name]
    }

    public func listAll() -> [ToolManifest] {
        tools.values.map(\.manifest)
    }

    public var count: Int {
        tools.count
    }

    public func contains(name: String) -> Bool {
        tools[name] != nil
    }
}

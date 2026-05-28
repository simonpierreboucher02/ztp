import Testing
import Foundation
@testable import ZTPCore
@testable import ZTPProtocols

struct MockTool: ZTPTool {
    let manifest: ToolManifest

    func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        ToolResult.success(tool: manifest.name, durationMs: 1)
    }
}

@Suite("ToolRegistry Tests")
struct ToolRegistryTests {

    @Test("Register and retrieve tool")
    func registerAndGet() {
        var registry = ToolRegistry()
        let tool = MockTool(manifest: ToolManifest(name: "mock-tool", version: "1.0.0"))
        registry.register(tool: tool)

        #expect(registry.count == 1)
        #expect(registry.contains(name: "mock-tool"))

        let retrieved = registry.get(name: "mock-tool")
        #expect(retrieved != nil)
        #expect(retrieved?.manifest.name == "mock-tool")
    }

    @Test("Get non-existent tool returns nil")
    func getMissing() {
        let registry = ToolRegistry()
        #expect(registry.get(name: "nonexistent") == nil)
    }

    @Test("List all tools")
    func listAll() {
        var registry = ToolRegistry()
        registry.register(tool: MockTool(manifest: ToolManifest(name: "tool-a", version: "1.0.0")))
        registry.register(tool: MockTool(manifest: ToolManifest(name: "tool-b", version: "2.0.0")))

        let manifests = registry.listAll()
        #expect(manifests.count == 2)

        let names = Set(manifests.map(\.name))
        #expect(names.contains("tool-a"))
        #expect(names.contains("tool-b"))
    }
}

import Testing
import Foundation
@testable import ZTPCore
@testable import ZTPProtocols

struct EchoTool: ZTPTool {
    let manifest = ToolManifest(name: "echo", version: "1.0.0")

    func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        let message = input.string(for: "message") ?? "no message"
        return ToolResult.success(
            tool: "echo",
            durationMs: 0,
            data: ["echo": .string(message)]
        )
    }
}

struct FailingTool: ZTPTool {
    let manifest = ToolManifest(name: "fail", version: "1.0.0")

    func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        throw ToolError.executionFailed("intentional failure")
    }
}

@Suite("ZTPRuntime Tests")
struct ZTPRuntimeTests {

    @Test("Execute registered tool")
    func executeRegisteredTool() async throws {
        let runtime = ZTPRuntime()
        await runtime.register(tool: EchoTool())

        let input = ToolInput(parameters: ["message": .string("hello")])
        let context = ToolContext()
        let result = await try runtime.execute(toolName: "echo", input: input, context: context)

        #expect(result.ok == true)
        #expect(result.tool == "echo")
        #expect(result.data?["echo"] == .string("hello"))
    }

    @Test("Execute unknown tool returns failure")
    func executeUnknown() async throws {
        let runtime = ZTPRuntime()
        let result = await try runtime.execute(
            toolName: "nonexistent",
            input: ToolInput(),
            context: ToolContext()
        )

        #expect(result.ok == false)
        #expect(result.error?.code == "NOT_FOUND")
    }

    @Test("Execute failing tool returns failure result")
    func executeFailingTool() async throws {
        let runtime = ZTPRuntime()
        await runtime.register(tool: FailingTool())

        let result = await try runtime.execute(
            toolName: "fail",
            input: ToolInput(),
            context: ToolContext()
        )

        #expect(result.ok == false)
        #expect(result.error?.code == "EXECUTION_FAILED")
    }

    @Test("List registered tools")
    func listTools() async {
        let runtime = ZTPRuntime()
        await runtime.register(tool: EchoTool())

        let tools = await runtime.listTools()
        #expect(tools.count == 1)
        #expect(tools[0].name == "echo")
    }
}

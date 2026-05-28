import Testing
import Foundation
@testable import ZTPDocx
@testable import ZTPProtocols

@Suite("ZTPDocx Tool Tests")
struct ZTPDocxTests {

    @Test("Manifest has correct name and capabilities")
    func manifest() {
        let tool = ZTPDocxTool()
        #expect(tool.manifest.name == "ztp-docx")
        #expect(tool.manifest.version == "0.1.0")
        #expect(tool.manifest.capabilities.contains("docx.create"))
        #expect(tool.manifest.capabilities.contains("docx.tables"))
        #expect(tool.manifest.capabilities.contains("docx.images"))
    }

    @Test("Execute without command returns error")
    func noCommand() async throws {
        let tool = ZTPDocxTool()
        let result = try await tool.execute(input: ToolInput(), context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "MISSING_COMMAND")
    }

    @Test("Execute with unknown command returns error")
    func unknownCommand() async throws {
        let tool = ZTPDocxTool()
        let input = ToolInput(parameters: ["command": .string("nonexistent")])
        let result = try await tool.execute(input: input, context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "UNKNOWN_COMMAND")
    }
}

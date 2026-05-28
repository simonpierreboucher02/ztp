import Testing
import Foundation
@testable import ZTPSlides
@testable import ZTPProtocols

@Suite("ZTPSlides Tool Tests")
struct ZTPSlidesTests {

    @Test("Manifest has correct name and capabilities")
    func manifest() {
        let tool = ZTPSlidesTool()
        #expect(tool.manifest.name == "ztp-slides")
        #expect(tool.manifest.version == "0.1.0")
        #expect(tool.manifest.capabilities.contains("pptx.create"))
        #expect(tool.manifest.capabilities.contains("pptx.table"))
        #expect(tool.manifest.capabilities.contains("pptx.theme"))
    }

    @Test("Execute without command returns error")
    func noCommand() async throws {
        let tool = ZTPSlidesTool()
        let result = try await tool.execute(input: ToolInput(), context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "MISSING_COMMAND")
    }

    @Test("Execute with unknown command returns error")
    func unknownCommand() async throws {
        let tool = ZTPSlidesTool()
        let input = ToolInput(parameters: ["command": .string("nonexistent")])
        let result = try await tool.execute(input: input, context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "UNKNOWN_COMMAND")
    }
}

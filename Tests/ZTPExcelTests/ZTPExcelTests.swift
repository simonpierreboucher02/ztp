import Testing
import Foundation
@testable import ZTPExcel
@testable import ZTPProtocols

@Suite("ZTPExcel Tests")
struct ZTPExcelTests {

    @Test("Manifest has correct name")
    func manifestName() {
        let tool = ZTPExcelTool()
        #expect(tool.manifest.name == "ztp-excel")
        #expect(tool.manifest.version == "0.1.0")
        #expect(tool.manifest.capabilities.contains("xlsx.create"))
        #expect(tool.manifest.capabilities.contains("csv.import"))
    }

    @Test("Execute without command returns error")
    func executeNoCommand() async throws {
        let tool = ZTPExcelTool()
        let result = try await tool.execute(input: ToolInput(), context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "MISSING_COMMAND")
    }

    @Test("Execute with unknown command returns error")
    func executeUnknownCommand() async throws {
        let tool = ZTPExcelTool()
        let input = ToolInput(parameters: ["command": .string("nonexistent")])
        let result = try await tool.execute(input: input, context: ToolContext())
        #expect(result.ok == false)
        #expect(result.error?.code == "UNKNOWN_COMMAND")
    }
}

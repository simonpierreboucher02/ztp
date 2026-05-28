import Testing
import Foundation
@testable import ZTPProtocols

@Suite("ToolResult Tests")
struct ToolResultTests {

    @Test("Create success result")
    func successResult() {
        let result = ToolResult.success(
            tool: "ztp-test",
            durationMs: 42,
            data: ["output": .string("done")]
        )
        #expect(result.ok == true)
        #expect(result.tool == "ztp-test")
        #expect(result.durationMs == 42)
        #expect(result.error == nil)
    }

    @Test("Create failure result")
    func failureResult() {
        let result = ToolResult.failure(
            tool: "ztp-test",
            error: ToolErrorInfo(code: "ERR", message: "something failed")
        )
        #expect(result.ok == false)
        #expect(result.error?.code == "ERR")
        #expect(result.error?.message == "something failed")
    }

    @Test("JSON encoding uses snake_case for duration")
    func jsonEncoding() throws {
        let result = ToolResult.success(tool: "ztp-test", durationMs: 100)
        let data = try JSONEncoder().encode(result)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("duration_ms"))
        #expect(!json.contains("durationMs"))
    }
}

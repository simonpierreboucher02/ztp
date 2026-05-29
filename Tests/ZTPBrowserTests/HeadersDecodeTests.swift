import Testing
import Foundation
@testable import ZTPBrowser

@Suite("Browser Custom Headers Tests")
struct HeadersDecodeTests {

    @Test("BrowserTask decodes custom headers")
    func decodeHeaders() throws {
        let json = """
        {"version":"ztp-browser/0.1","task":{"action":"html","url":"https://example.com",
        "headers":{"Authorization":"Bearer xyz","Accept":"application/json"}}}
        """
        let spec = try JSONDecoder().decode(BrowserSpec.self, from: Data(json.utf8))
        #expect(spec.task.headers?["Authorization"] == "Bearer xyz")
        #expect(spec.task.headers?["Accept"] == "application/json")
    }

    @Test("Headers are optional")
    func headersOptional() throws {
        let json = """
        {"version":"ztp-browser/0.1","task":{"action":"text","url":"https://example.com"}}
        """
        let spec = try JSONDecoder().decode(BrowserSpec.self, from: Data(json.utf8))
        #expect(spec.task.headers == nil)
    }
}

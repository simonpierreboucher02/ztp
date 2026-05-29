import Testing
import Foundation
@testable import ZTPNotes

@Suite("ZTPNotes Tests")
struct ZTPNotesTests {
    @Test("Manifest name + capabilities")
    func manifest() {
        let tool = ZTPNotesTool()
        #expect(tool.manifest.name == "ztp-notes")
        #expect(tool.manifest.capabilities.contains("create"))
        #expect(tool.manifest.capabilities.contains("read"))
        #expect(tool.manifest.permissions["applescript"] == true)
    }

    @Test("HTML escaping")
    func htmlEscape() {
        #expect(NotesBridge.htmlEscape("a < b & c > d") == "a &lt; b &amp; c &gt; d")
    }

    @Test("Body HTML embeds title")
    func bodyHTML() {
        let html = NotesBridge.makeBodyHTML(title: "Hello", body: "world")
        #expect(html.contains("<h1>Hello</h1>"))
        #expect(html.contains("world"))
    }

    @Test("Plain-text body becomes div lines")
    func bodyDivs() {
        let out = NotesBridge.escapeForBody("line1\nline2")
        #expect(out.contains("<div>line1</div>"))
        #expect(out.contains("<div>line2</div>"))
    }

    @Test("Existing HTML body kept as-is")
    func htmlPassthrough() {
        let out = NotesBridge.escapeForBody("<p>hi</p>")
        #expect(out == "<p>hi</p>")
    }

    @Test("stripHTML reduces tags")
    func strip() {
        let text = NotesBridge.stripHTML("<div>Hello</div><div>World</div>")
        #expect(text.contains("Hello"))
        #expect(text.contains("World"))
        #expect(!text.contains("<div>"))
    }
}

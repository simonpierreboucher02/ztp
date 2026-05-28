import Testing
@testable import ZTPExcel

@Suite("XML Escaping Tests")
struct XMLEscapingTests {

    @Test("Escapes ampersand")
    func escapeAmpersand() {
        #expect(XMLEscaping.escape("A&B") == "A&amp;B")
    }

    @Test("Escapes angle brackets")
    func escapeBrackets() {
        #expect(XMLEscaping.escape("<tag>") == "&lt;tag&gt;")
    }

    @Test("Escapes quotes")
    func escapeQuotes() {
        #expect(XMLEscaping.escape("He said \"hi\"") == "He said &quot;hi&quot;")
    }

    @Test("No-op on clean string")
    func noEscape() {
        #expect(XMLEscaping.escape("Hello World") == "Hello World")
    }

    @Test("Handles all special characters together")
    func allSpecial() {
        let input = "<a & 'b' \"c\">"
        let expected = "&lt;a &amp; &apos;b&apos; &quot;c&quot;&gt;"
        #expect(XMLEscaping.escape(input) == expected)
    }
}

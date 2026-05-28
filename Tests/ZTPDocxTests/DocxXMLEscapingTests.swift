import Testing
@testable import ZTPDocx

@Suite("DOCX XML Escaping Tests")
struct DocxXMLEscapingTests {

    @Test("Escapes all special characters")
    func allSpecial() {
        let input = "<a & 'b' \"c\">"
        let expected = "&lt;a &amp; &apos;b&apos; &quot;c&quot;&gt;"
        #expect(DocxXMLEscaping.escape(input) == expected)
    }

    @Test("No-op on clean string")
    func noEscape() {
        #expect(DocxXMLEscaping.escape("Hello World") == "Hello World")
    }
}

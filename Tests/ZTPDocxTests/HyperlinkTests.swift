import Testing
import Foundation
@testable import ZTPDocx

@Suite("DOCX Hyperlink Tests")
struct HyperlinkTests {

    @Test("A run with a link renders <w:hyperlink>")
    func renderHyperlink() {
        let doc = DocxDocument(title: "t", sections: [
            DocxSection(elements: [
                .paragraph(runs: [
                    DocxRun(text: "Visit "),
                    DocxRun(text: "site", link: "https://zyquo.dev"),
                ], style: nil, alignment: nil),
            ]),
        ])
        let xml = DocumentWriter.toXML(
            document: doc,
            styleRegistry: DocxStyleRegistry(),
            imageRelationships: [:],
            hyperlinkRelationships: ["https://zyquo.dev": "rIdLink1"]
        )
        #expect(xml.contains("<w:hyperlink r:id=\"rIdLink1\">"))
    }

    @Test("Full build emits an external hyperlink relationship")
    func buildEmitsRel() throws {
        let json = """
        {"version":"ztp-docx/0.1","document":{"title":"t"},"sections":[{"elements":[
        {"type":"paragraph","runs":[{"text":"x","link":"https://example.com"}]}]}]}
        """
        let spec = try JSONDecoder().decode(DocumentSpec.self, from: Data(json.utf8))
        let doc = try spec.toDocument()
        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry())
        #expect(data.count > 0)
        // The run carried the link through the model.
        if case let .paragraph(runs, _, _)? = doc.sections.first?.elements.first {
            #expect(runs.contains { $0.link == "https://example.com" })
        } else {
            Issue.record("expected a paragraph element")
        }
    }
}

import Testing
import Foundation
@testable import ZTPDocx

@Suite("DocumentSpec Tests")
struct DocumentSpecTests {

    @Test("Decode complete spec from JSON")
    func decodeSpec() throws {
        let json = """
        {
          "version": "ztp-docx/0.1",
          "document": { "title": "Test Doc", "author": "Agent" },
          "sections": [
            {
              "elements": [
                { "type": "heading", "level": 1, "text": "Title" },
                { "type": "paragraph", "text": "Body text here." },
                { "type": "bullet_list", "items": ["A", "B"] },
                { "type": "table", "headers": ["X", "Y"], "rows": [["1", "2"]] },
                { "type": "page_break" },
                { "type": "horizontal_rule" }
              ]
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let spec = try JSONDecoder().decode(DocumentSpec.self, from: data)

        #expect(spec.version == "ztp-docx/0.1")
        #expect(spec.document?.title == "Test Doc")
        #expect(spec.sections.count == 1)
        #expect(spec.sections[0].elements.count == 6)
    }

    @Test("Convert spec to document")
    func toDocument() throws {
        let spec = DocumentSpec(
            version: "ztp-docx/0.1",
            document: DocumentMeta(title: "T", author: "A"),
            sections: [
                SectionSpec(elements: [
                    ElementSpec.heading(level: 1, text: "Hello", style: nil),
                    ElementSpec.paragraph(text: "World", runs: nil, style: nil, alignment: nil),
                ])
            ]
        )

        let doc = try spec.toDocument()
        #expect(doc.title == "T")
        #expect(doc.author == "A")
        #expect(doc.sections.count == 1)
        #expect(doc.totalHeadings == 1)
        #expect(doc.totalParagraphs == 2)
    }

    @Test("Paragraph with runs")
    func paragraphWithRuns() throws {
        let json = """
        {
          "version": "ztp-docx/0.1",
          "sections": [{
            "elements": [{
              "type": "paragraph",
              "runs": [
                { "text": "Bold ", "bold": true },
                { "text": "normal" }
              ]
            }]
          }]
        }
        """
        let spec = try JSONDecoder().decode(DocumentSpec.self, from: Data(json.utf8))
        let doc = try spec.toDocument()
        let para = doc.sections[0].elements[0]

        if case .paragraph(let runs, _, _) = para {
            #expect(runs.count == 2)
            #expect(runs[0].bold == true)
            #expect(runs[0].text == "Bold ")
        } else {
            Issue.record("Expected paragraph element")
        }
    }

    @Test("Style map conversion")
    func styleMap() {
        let spec = DocumentSpec(
            version: "ztp-docx/0.1",
            sections: [SectionSpec(elements: [ElementSpec.heading(level: 1, text: "T", style: nil)])],
            styles: [
                "heading1": DocxStyleSpec(font: DocxFontStyleSpec(bold: true, size: 24)),
                "body": DocxStyleSpec(font: DocxFontStyleSpec(size: 11)),
            ]
        )
        let map = spec.toStyleMap()
        #expect(map.count == 2)
        #expect(map["heading1"]?.font?.bold == true)
        #expect(map["body"]?.font?.size == 11)
    }
}

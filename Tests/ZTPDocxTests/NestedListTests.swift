import Testing
import Foundation
@testable import ZTPDocx

@Suite("Nested List Tests")
struct NestedListTests {

    @Test("List items decode from string or object with level")
    func itemDecoding() throws {
        let json = """
        {"type":"bullet_list","items":["Top",{"text":"Sub","level":1}]}
        """
        let el = try JSONDecoder().decode(DocxElement.self, from: Data(json.utf8))
        guard case let .bulletList(items) = el else { Issue.record("expected bullet_list"); return }
        #expect(items.count == 2)
        #expect(items[0].text == "Top" && items[0].level == 0)
        #expect(items[1].text == "Sub" && items[1].level == 1)
    }

    @Test("Nested levels render distinct w:ilvl values")
    func rendersLevels() {
        let doc = DocxDocument(title: "t", sections: [
            DocxSection(elements: [
                .bulletList(items: ["A", DocxListItem(text: "A1", level: 1), DocxListItem(text: "deep", level: 2)]),
            ]),
        ])
        let xml = DocumentWriter.toXML(document: doc, styleRegistry: DocxStyleRegistry(), imageRelationships: [:])
        #expect(xml.contains("<w:ilvl w:val=\"0\"/>"))
        #expect(xml.contains("<w:ilvl w:val=\"1\"/>"))
        #expect(xml.contains("<w:ilvl w:val=\"2\"/>"))
    }

    @Test("Levels are clamped to 0...8")
    func clamp() {
        #expect(DocxListItem(text: "x", level: 99).level == 8)
        #expect(DocxListItem(text: "x", level: -3).level == 0)
    }
}

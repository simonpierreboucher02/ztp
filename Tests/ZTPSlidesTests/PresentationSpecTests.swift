import Testing
import Foundation
@testable import ZTPSlides

@Suite("PresentationSpec Tests")
struct PresentationSpecTests {

    @Test("Decode complete spec from JSON")
    func decodeSpec() throws {
        let json = """
        {
          "version": "ztp-slides/0.1",
          "presentation": { "title": "Test", "author": "Agent", "size": "16:9" },
          "theme": { "name": "test-theme", "font": "Arial", "accent": "#FF0000" },
          "slides": [
            { "layout": "title", "title": "Hello", "subtitle": "World" },
            { "layout": "title-content", "title": "Content", "content": [
              { "type": "bullets", "items": ["A", "B"] }
            ]}
          ]
        }
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        #expect(spec.version == "ztp-slides/0.1")
        #expect(spec.slides.count == 2)
    }

    @Test("Convert spec to presentation")
    func toPresentation() throws {
        let json = """
        {
          "version": "ztp-slides/0.1",
          "presentation": { "title": "T", "author": "A" },
          "slides": [
            { "layout": "title", "title": "Slide 1" },
            { "layout": "table", "title": "Data", "table": { "headers": ["X","Y"], "rows": [["1","2"]] } }
          ]
        }
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let pres = try spec.toPresentation()
        #expect(pres.title == "T")
        #expect(pres.totalSlides == 2)
        #expect(pres.totalTables == 1)
    }

    @Test("Strip hash from accent color")
    func stripHash() throws {
        let json = """
        {"version":"ztp-slides/0.1","theme":{"accent":"#3B82F6"},"slides":[{"layout":"blank"}]}
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let pres = try spec.toPresentation()
        #expect(pres.theme.accent == "3B82F6")
    }
}

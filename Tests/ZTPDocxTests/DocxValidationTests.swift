import Testing
import Foundation
@testable import ZTPDocx

@Suite("DOCX Validation Tests")
struct DocxValidationTests {

    @Test("Valid spec passes")
    func validSpec() {
        let spec = DocumentSpec(
            version: "ztp-docx/0.1",
            sections: [
                SectionSpec(elements: [
                    ElementSpec.heading(level: 1, text: "Title", style: nil),
                ])
            ]
        )
        let result = DocxSpecValidator.validate(spec: spec)
        #expect(result.valid)
    }

    @Test("Invalid version fails")
    func invalidVersion() {
        let spec = DocumentSpec(
            version: "wrong",
            sections: [SectionSpec(elements: [ElementSpec.heading(level: 1, text: "T", style: nil)])]
        )
        let result = DocxSpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "INVALID_VERSION" })
    }

    @Test("Empty sections fails")
    func emptySections() {
        let spec = DocumentSpec(version: "ztp-docx/0.1", sections: [])
        let result = DocxSpecValidator.validate(spec: spec)
        #expect(!result.valid)
    }

    @Test("Invalid heading level fails")
    func invalidHeadingLevel() {
        let spec = DocumentSpec(version: "ztp-docx/0.1", sections: [
            SectionSpec(elements: [ElementSpec.heading(level: 10, text: "Bad", style: nil)])
        ])
        let result = DocxSpecValidator.validate(spec: spec)
        #expect(!result.valid)
    }

    @Test("Empty heading text fails")
    func emptyHeadingText() {
        let spec = DocumentSpec(version: "ztp-docx/0.1", sections: [
            SectionSpec(elements: [ElementSpec.heading(level: 1, text: "", style: nil)])
        ])
        let result = DocxSpecValidator.validate(spec: spec)
        #expect(!result.valid)
    }

    @Test("Valid JSON data")
    func validJSON() {
        let json = """
        {"version":"ztp-docx/0.1","sections":[{"elements":[{"type":"paragraph","text":"Hello"}]}]}
        """
        let result = DocxSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid JSON fails gracefully")
    func invalidJSON() {
        let result = DocxSpecValidator.validate(jsonData: Data("not json".utf8))
        #expect(!result.valid)
    }

    @Test("DOCX validation on generated file")
    func docxValidation() throws {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .paragraph(runs: [DocxRun(text: "test")], style: nil, alignment: nil)
            ])
        ])
        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        let tmpPath = NSTemporaryDirectory() + "ztp_test_validate.docx"
        try data.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let result = try DocxValidator.validate(at: tmpPath)
        #expect(result.valid)
    }
}

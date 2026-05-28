import Testing
import Foundation
@testable import ZTPSlides

@Suite("Slides Validation Tests")
struct SlidesValidationTests {

    @Test("Valid spec passes")
    func validSpec() throws {
        let json = """
        {"version":"ztp-slides/0.1","slides":[{"layout":"title","title":"Hi"}]}
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let result = SlidesSpecValidator.validate(spec: spec)
        #expect(result.valid)
    }

    @Test("Invalid version fails")
    func invalidVersion() throws {
        let json = """
        {"version":"wrong","slides":[{"layout":"title","title":"Hi"}]}
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let result = SlidesSpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "INVALID_VERSION" })
    }

    @Test("Empty slides fails")
    func emptySlides() throws {
        let json = """
        {"version":"ztp-slides/0.1","slides":[]}
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let result = SlidesSpecValidator.validate(spec: spec)
        #expect(!result.valid)
    }

    @Test("Valid JSON data")
    func validJSON() {
        let json = """
        {"version":"ztp-slides/0.1","slides":[{"layout":"blank"}]}
        """
        let result = SlidesSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid JSON fails gracefully")
    func invalidJSON() {
        let result = SlidesSpecValidator.validate(jsonData: Data("not json".utf8))
        #expect(!result.valid)
    }

    @Test("PPTX validation on generated file")
    func pptxValidation() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .title, title: "Test"),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        let tmpPath = NSTemporaryDirectory() + "ztp_test_validate.pptx"
        try data.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let result = try SlidesValidator.validate(at: tmpPath)
        #expect(result.valid)
    }
}

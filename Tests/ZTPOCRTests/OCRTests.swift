import Testing
import Foundation
@testable import ZTPOCR

@Suite("ZTPOCR Tests")
struct ZTPOCRTests {
    @Test("Manifest name + capabilities")
    func manifest() {
        let tool = ZTPOCRTool()
        #expect(tool.manifest.name == "ztp-ocr")
        #expect(tool.manifest.capabilities.contains("image"))
        #expect(tool.manifest.capabilities.contains("pdf"))
        #expect(tool.manifest.capabilities.contains("screen"))
    }

    @Test("Page range parsing")
    func pageRange() {
        #expect(PDFRasterizer.parsePageRange(nil) == nil)
        #expect(PDFRasterizer.parsePageRange("") == nil)
        #expect(PDFRasterizer.parsePageRange("1") == [0])
        #expect(PDFRasterizer.parsePageRange("1-3") == [0, 1, 2])
        #expect(PDFRasterizer.parsePageRange("1,3,5") == [0, 2, 4])
        #expect(PDFRasterizer.parsePageRange("2-4,7") == [1, 2, 3, 6])
    }

    @Test("Supported languages is non-empty")
    func languages() {
        let langs = OCREngine.supportedLanguages()
        #expect(!langs.isEmpty)
    }

    @Test("Missing image throws")
    func missingImage() {
        #expect(throws: (any Error).self) {
            _ = try OCREngine.recognizeImage(path: "/nonexistent_\(UUID().uuidString).png")
        }
    }
}

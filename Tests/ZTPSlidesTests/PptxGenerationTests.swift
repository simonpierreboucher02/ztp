import Testing
import Foundation
@testable import ZTPSlides

@Suite("PPTX Generation Tests")
struct PptxGenerationTests {

    @Test("Generate minimal presentation")
    func minimal() throws {
        let pres = PptxPresentation(title: "Test", slides: [
            PptxSlide(layout: .title, title: "Hello", subtitle: "World"),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
        #expect(data[0] == 0x50)
        #expect(data[1] == 0x4B)
    }

    @Test("Generate presentation with bullets")
    func bullets() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .titleContent, title: "Points", content: [
                .bullets(["First", "Second", "Third"]),
            ]),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate presentation with table")
    func table() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .table, title: "Data", content: [
                .table(PptxTable(headers: ["A", "B"], rows: [["1", "2"]])),
            ]),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate multi-slide presentation")
    func multiSlide() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .title, title: "Slide 1"),
            PptxSlide(layout: .titleContent, title: "Slide 2", content: [.paragraph("Text", style: nil)]),
            PptxSlide(layout: .sectionDivider, title: "End"),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate with KPI element")
    func kpi() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .blank, content: [
                .kpi(label: "Revenue", value: "$150K", delta: "+12%"),
            ]),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate with shapes")
    func shapes() throws {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .blank, content: [
                .shape(PptxShape(type: .rectangle, text: "Box", fillColor: "3B82F6")),
            ]),
        ])
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Round-trip: build then inspect")
    func roundTrip() throws {
        let pres = PptxPresentation(
            title: "RoundTrip",
            author: "Test",
            slides: [
                PptxSlide(layout: .title, title: "Title Slide"),
                PptxSlide(layout: .titleContent, title: "Content", content: [
                    .bullets(["A", "B"]),
                ]),
                PptxSlide(layout: .table, title: "Table", content: [
                    .table(PptxTable(headers: ["X"], rows: [["1"]])),
                ]),
            ]
        )
        let data = try PptxPackager.package(presentation: pres, basePath: nil)
        let tmpPath = NSTemporaryDirectory() + "ztp_test_roundtrip.pptx"
        try data.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let info = try SlidesInspector.inspect(at: tmpPath)
        #expect(info.slides == 3)
        #expect(info.tables == 1)
        #expect(info.title == "RoundTrip")
    }

    @Test("Computed properties")
    func computedProperties() {
        let pres = PptxPresentation(slides: [
            PptxSlide(layout: .title, title: "T"),
            PptxSlide(layout: .blank, content: [
                .table(PptxTable(rows: [["a"]])),
                .image(PptxImage(path: "test.png")),
            ]),
        ])
        #expect(pres.totalSlides == 2)
        #expect(pres.totalTables == 1)
        #expect(pres.totalImages == 1)
    }
}

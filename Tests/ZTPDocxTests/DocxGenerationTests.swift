import Testing
import Foundation
@testable import ZTPDocx

@Suite("DOCX Generation Tests")
struct DocxGenerationTests {

    @Test("Generate minimal document")
    func minimalDocument() throws {
        let doc = DocxDocument(
            title: "Test",
            author: "Unit",
            sections: [
                DocxSection(elements: [
                    .heading(level: 1, text: "Title", style: nil),
                    .paragraph(runs: [DocxRun(text: "Hello world.")], style: nil, alignment: nil),
                ])
            ]
        )

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        #expect(data.count > 0)
        #expect(data[0] == 0x50) // P
        #expect(data[1] == 0x4B) // K
    }

    @Test("Generate document with table")
    func tableDocument() throws {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .table(DocxTable(headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]])),
            ])
        ])

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate document with lists")
    func listDocument() throws {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .bulletList(items: ["First", "Second", "Third"]),
                .numberedList(items: ["One", "Two", "Three"]),
            ])
        ])

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate document with page break and horizontal rule")
    func specialElements() throws {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .paragraph(runs: [DocxRun(text: "Page 1")], style: nil, alignment: nil),
                .pageBreak,
                .paragraph(runs: [DocxRun(text: "Page 2")], style: nil, alignment: nil),
                .horizontalRule,
            ])
        ])

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate document with styles")
    func styledDocument() throws {
        var registry = DocxStyleRegistry()
        registry.register(name: "emphasis", style: DocxStyle(
            font: DocxFontStyle(bold: true, italic: true, color: "FF0000")
        ))

        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .paragraph(runs: [DocxRun(text: "Styled text")], style: "emphasis", alignment: .center),
            ])
        ])

        let data = try DocxPackager.package(document: doc, styleRegistry: registry, basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Generate multi-section document")
    func multiSection() throws {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .heading(level: 1, text: "Section 1", style: nil),
                .paragraph(runs: [DocxRun(text: "Content 1")], style: nil, alignment: nil),
            ]),
            DocxSection(elements: [
                .heading(level: 1, text: "Section 2", style: nil),
                .paragraph(runs: [DocxRun(text: "Content 2")], style: nil, alignment: nil),
            ]),
        ])

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        #expect(data.count > 0)
    }

    @Test("Round-trip: build then inspect")
    func roundTrip() throws {
        let doc = DocxDocument(
            title: "RoundTrip",
            author: "Test",
            sections: [
                DocxSection(elements: [
                    .heading(level: 1, text: "Main Title", style: nil),
                    .paragraph(runs: [DocxRun(text: "Paragraph one.")], style: nil, alignment: nil),
                    .heading(level: 2, text: "Sub Heading", style: nil),
                    .table(DocxTable(headers: ["Col1", "Col2"], rows: [["A", "B"]])),
                ])
            ]
        )

        let data = try DocxPackager.package(document: doc, styleRegistry: DocxStyleRegistry(), basePath: nil)
        let tmpPath = NSTemporaryDirectory() + "ztp_test_roundtrip.docx"
        try data.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let info = try DocxInspector.inspect(at: tmpPath)
        #expect(info.title == "RoundTrip")
        #expect(info.author == "Test")
        #expect(info.headings >= 2)
        #expect(info.tables == 1)
    }

    @Test("Document computed properties")
    func computedProperties() {
        let doc = DocxDocument(sections: [
            DocxSection(elements: [
                .heading(level: 1, text: "H1", style: nil),
                .paragraph(runs: [DocxRun(text: "P1")], style: nil, alignment: nil),
                .table(DocxTable(rows: [["a"]])),
                .heading(level: 2, text: "H2", style: nil),
            ])
        ])

        #expect(doc.totalHeadings == 2)
        #expect(doc.totalParagraphs == 3) // 2 headings + 1 paragraph
        #expect(doc.totalTables == 1)
        #expect(doc.totalImages == 0)
    }
}

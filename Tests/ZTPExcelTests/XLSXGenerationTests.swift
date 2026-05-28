import Testing
import Foundation
@testable import ZTPExcel

@Suite("XLSX Generation Tests")
struct XLSXGenerationTests {

    @Test("Generate minimal workbook")
    func minimalWorkbook() throws {
        let workbook = Workbook(
            title: "Test",
            author: "Unit",
            sheets: [
                Worksheet(name: "Sheet1", cells: [
                    Cell(address: CellAddress(column: 1, row: 1), value: .string("Hello")),
                    Cell(address: CellAddress(column: 2, row: 1), value: .integer(42)),
                ])
            ]
        )

        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())
        #expect(data.count > 0)

        // Verify it's a valid ZIP (starts with PK signature)
        #expect(data[0] == 0x50) // P
        #expect(data[1] == 0x4B) // K
    }

    @Test("Generate workbook with formulas")
    func formulaWorkbook() throws {
        let workbook = Workbook(sheets: [
            Worksheet(name: "Calc", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .integer(10)),
                Cell(address: CellAddress(column: 1, row: 2), value: .integer(20)),
                Cell(address: CellAddress(column: 1, row: 3), value: .formula("SUM(A1:A2)")),
            ])
        ])

        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())
        #expect(data.count > 0)
    }

    @Test("Generate workbook with styles")
    func styledWorkbook() throws {
        var registry = StyleRegistry()
        registry.register(name: "bold", style: CellStyle(
            font: FontStyle(bold: true, size: 14)
        ))

        let workbook = Workbook(sheets: [
            Worksheet(name: "Styled", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .string("Title"), styleName: "bold"),
            ])
        ])

        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: registry)
        #expect(data.count > 0)
    }

    @Test("Generate workbook with multiple sheets")
    func multiSheet() throws {
        let workbook = Workbook(sheets: [
            Worksheet(name: "Sheet1", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .string("A")),
            ]),
            Worksheet(name: "Sheet2", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .string("B")),
            ]),
            Worksheet(name: "Sheet3", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .string("C")),
            ]),
        ])

        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())

        let entries = try ZIPReader.readEntries(from: data)
        let paths = entries.map(\.path)

        #expect(paths.contains("xl/worksheets/sheet1.xml"))
        #expect(paths.contains("xl/worksheets/sheet2.xml"))
        #expect(paths.contains("xl/worksheets/sheet3.xml"))
    }

    @Test("Round-trip: build then inspect")
    func roundTrip() throws {
        let workbook = Workbook(
            title: "RoundTrip",
            sheets: [
                Worksheet(name: "Data", cells: [
                    Cell(address: CellAddress(column: 1, row: 1), value: .string("Name")),
                    Cell(address: CellAddress(column: 2, row: 1), value: .string("Value")),
                    Cell(address: CellAddress(column: 1, row: 2), value: .string("Pi")),
                    Cell(address: CellAddress(column: 2, row: 2), value: .number(3.14159)),
                ])
            ]
        )

        let xlsxData = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())

        let tmpPath = NSTemporaryDirectory() + "ztp_test_roundtrip.xlsx"
        try xlsxData.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let info = try XLSXInspector.inspect(at: tmpPath)
        #expect(info.sheets == 1)
        #expect(info.sheetDetails[0].name == "Data")
        #expect(info.sheetDetails[0].rowsDetected == 2)
        #expect(info.sheetDetails[0].columnsDetected == 2)
    }

    @Test("Boolean values encode correctly")
    func booleanValues() throws {
        let workbook = Workbook(sheets: [
            Worksheet(name: "Bools", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .boolean(true)),
                Cell(address: CellAddress(column: 1, row: 2), value: .boolean(false)),
            ])
        ])

        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())
        #expect(data.count > 0)
    }
}

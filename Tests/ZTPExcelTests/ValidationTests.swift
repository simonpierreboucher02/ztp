import Testing
import Foundation
@testable import ZTPExcel

@Suite("Validation Tests")
struct ValidationTests {

    @Test("Valid spec passes validation")
    func validSpec() {
        let spec = WorkbookSpec(
            version: "ztp-excel/0.1",
            sheets: [
                SheetSpec(name: "Sheet1", cells: [
                    CellSpec(address: "A1", value: .string("test"))
                ])
            ]
        )
        let result = SpecValidator.validate(spec: spec)
        #expect(result.valid)
        #expect(result.errors.isEmpty)
    }

    @Test("Invalid version fails")
    func invalidVersion() {
        let spec = WorkbookSpec(
            version: "wrong",
            sheets: [SheetSpec(name: "S1")]
        )
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "INVALID_VERSION" })
    }

    @Test("Empty sheets fails")
    func emptySheets() {
        let spec = WorkbookSpec(sheets: [])
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
    }

    @Test("Duplicate sheet names fail")
    func duplicateSheetNames() {
        let spec = WorkbookSpec(sheets: [
            SheetSpec(name: "Data"),
            SheetSpec(name: "Data"),
        ])
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "DUPLICATE_SHEET_NAME" })
    }

    @Test("Invalid cell address fails")
    func invalidCellAddress() {
        let spec = WorkbookSpec(sheets: [
            SheetSpec(name: "S1", cells: [
                CellSpec(address: "ZZZZ1")
            ])
        ])
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "INVALID_CELL_ADDRESS" })
    }

    @Test("Unknown style reference fails")
    func unknownStyle() {
        let spec = WorkbookSpec(
            sheets: [
                SheetSpec(name: "S1", cells: [
                    CellSpec(address: "A1", value: .string("x"), style: "nonexistent")
                ])
            ],
            styles: [:]
        )
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "UNDEFINED_STYLE" })
    }

    @Test("Duplicate cell addresses fail")
    func duplicateCells() {
        let spec = WorkbookSpec(sheets: [
            SheetSpec(name: "S1", cells: [
                CellSpec(address: "A1", value: .string("first")),
                CellSpec(address: "A1", value: .string("second")),
            ])
        ])
        let result = SpecValidator.validate(spec: spec)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "DUPLICATE_CELL_ADDRESS" })
    }

    @Test("XLSX validation on generated file")
    func xlsxValidation() throws {
        let workbook = Workbook(sheets: [
            Worksheet(name: "Test", cells: [
                Cell(address: CellAddress(column: 1, row: 1), value: .string("ok"))
            ])
        ])
        let data = try XLSXPackager.package(workbook: workbook, styleRegistry: StyleRegistry())

        let tmpPath = NSTemporaryDirectory() + "ztp_test_validate.xlsx"
        try data.write(to: URL(fileURLWithPath: tmpPath))
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let result = try XLSXValidator.validate(at: tmpPath)
        #expect(result.valid)
    }

    @Test("JSON data validation")
    func jsonValidation() {
        let json = """
        {"version":"ztp-excel/0.1","sheets":[{"name":"S1","cells":[{"address":"A1","value":"hello"}]}]}
        """
        let result = SpecValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid JSON fails gracefully")
    func invalidJSON() {
        let result = SpecValidator.validate(jsonData: Data("not json".utf8))
        #expect(!result.valid)
    }
}

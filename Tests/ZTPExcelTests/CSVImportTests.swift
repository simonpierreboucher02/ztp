import Testing
import Foundation
@testable import ZTPExcel

@Suite("CSV Import Tests")
struct CSVImportTests {

    @Test("Import simple CSV")
    func simpleCSV() throws {
        let csv = "Name,Age\nAlice,30\nBob,25\n"
        let data = Data(csv.utf8)
        let workbook = try CSVImporter.importCSV(from: data)

        #expect(workbook.sheets.count == 1)
        #expect(workbook.sheets[0].cells.count == 6)
    }

    @Test("Import with type inference")
    func typeInference() throws {
        let csv = "Label,Count,Active\nTest,42,true\n"
        let data = Data(csv.utf8)
        let options = CSVImporter.Options(inferTypes: true)
        let workbook = try CSVImporter.importCSV(from: data, options: options)

        let cells = workbook.sheets[0].cells
        let countCell = cells.first { $0.address.column == 2 && $0.address.row == 2 }
        let activeCell = cells.first { $0.address.column == 3 && $0.address.row == 2 }

        #expect(countCell?.value == .integer(42))
        #expect(activeCell?.value == .boolean(true))
    }

    @Test("Auto-detect semicolon delimiter")
    func semicolonDelimiter() throws {
        let csv = "A;B;C\n1;2;3\n"
        let data = Data(csv.utf8)
        let workbook = try CSVImporter.importCSV(from: data)

        #expect(workbook.sheets[0].cells.count == 6)
    }

    @Test("Handle quoted fields")
    func quotedFields() throws {
        let csv = "Name,Note\nAlice,\"Hello, World\"\nBob,\"He said \"\"hi\"\"\"\n"
        let data = Data(csv.utf8)
        let workbook = try CSVImporter.importCSV(from: data)

        let cells = workbook.sheets[0].cells
        let note1 = cells.first { $0.address.column == 2 && $0.address.row == 2 }
        #expect(note1?.value == .string("Hello, World"))
    }

    @Test("Custom sheet name")
    func customSheetName() throws {
        let csv = "A\n1\n"
        let data = Data(csv.utf8)
        let options = CSVImporter.Options(sheetName: "MyData")
        let workbook = try CSVImporter.importCSV(from: data, options: options)

        #expect(workbook.sheets[0].name == "MyData")
    }
}

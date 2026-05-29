import Testing
import Foundation
@testable import ZTPExcel

@Suite("Worksheet Feature Tests")
struct WorksheetFeatureTests {

    private func renderXML(_ ws: Worksheet) -> String {
        var sst = SharedStringTable()
        let registry = StyleRegistry()
        return WorksheetWriter.toXML(worksheet: ws, sharedStrings: &sst, styleRegistry: registry)
    }

    @Test("Merged cells render <mergeCell>")
    func merges() {
        let ws = Worksheet(name: "S", cells: [], merges: ["A1:C1", "A2:A4"])
        let xml = renderXML(ws)
        #expect(xml.contains("<mergeCells count=\"2\">"))
        #expect(xml.contains("<mergeCell ref=\"A1:C1\"/>"))
    }

    @Test("Column widths render <col>")
    func columns() {
        let ws = Worksheet(name: "S", columnWidths: [ColumnWidth(min: 1, max: 1, width: 24), ColumnWidth(min: 2, max: 3, width: 14)])
        let xml = renderXML(ws)
        #expect(xml.contains("<col min=\"1\" max=\"1\" width=\"24\" customWidth=\"1\"/>"))
        #expect(xml.contains("<col min=\"2\" max=\"3\""))
    }

    @Test("Frozen rows render a frozen pane")
    func freeze() {
        let ws = Worksheet(name: "S", freezeRows: 1)
        let xml = renderXML(ws)
        #expect(xml.contains("state=\"frozen\""))
        #expect(xml.contains("ySplit=\"1\""))
        #expect(xml.contains("topLeftCell=\"A2\""))
    }

    @Test("Spec round-trips merges/columns/freeze into the workbook")
    func specConversion() throws {
        let json = """
        {"version":"ztp-excel/0.1","sheets":[{"name":"S","freeze":{"rows":1,"columns":1},
        "columns":[{"column":"A","width":20}],"merges":["A1:B1"],
        "cells":[{"address":"A1","value":"x"}]}]}
        """
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: Data(json.utf8))
        let wb = try spec.toWorkbook()
        let sheet = wb.sheets[0]
        #expect(sheet.merges == ["A1:B1"])
        #expect(sheet.freezeRows == 1)
        #expect(sheet.freezeColumns == 1)
        #expect(sheet.columnWidths.first?.width == 20)
    }
}

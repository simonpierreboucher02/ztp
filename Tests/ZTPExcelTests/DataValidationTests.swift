import Testing
import Foundation
@testable import ZTPExcel

@Suite("Excel Data Validation Tests")
struct DataValidationTests {

    private func renderXML(_ ws: Worksheet) -> String {
        var sst = SharedStringTable()
        let registry = StyleRegistry()
        return WorksheetWriter.toXML(worksheet: ws, sharedStrings: &sst, styleRegistry: registry)
    }

    @Test("List validation renders a dropdown")
    func listDropdown() {
        let ws = Worksheet(name: "S", dataValidations: [
            DataValidation(sqref: "A2:A10", type: "list", formula1: "\"X,Y,Z\""),
        ])
        let xml = renderXML(ws)
        #expect(xml.contains("<dataValidation type=\"list\""))
        #expect(xml.contains("sqref=\"A2:A10\""))
        #expect(xml.contains("&quot;X,Y,Z&quot;"))
    }

    @Test("Numeric range validation uses operator=between")
    func numericRange() {
        let ws = Worksheet(name: "S", dataValidations: [
            DataValidation(sqref: "B2:B10", type: "whole", formula1: "1", formula2: "10"),
        ])
        let xml = renderXML(ws)
        #expect(xml.contains("type=\"whole\""))
        #expect(xml.contains("operator=\"between\""))
        #expect(xml.contains("<formula2>10</formula2>"))
    }

    @Test("Spec converts validations into the worksheet")
    func specConversion() throws {
        let json = """
        {"version":"ztp-excel/0.1","sheets":[{"name":"S","validations":[
        {"range":"A1:A5","type":"list","values":["a","b"]}],"cells":[{"address":"A1","value":"x"}]}]}
        """
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: Data(json.utf8))
        let wb = try spec.toWorkbook()
        #expect(wb.sheets[0].dataValidations.first?.type == "list")
        #expect(wb.sheets[0].dataValidations.first?.formula1 == "\"a,b\"")
    }

    @Test("Cell comments produce parts and a legacyDrawing reference")
    func cellComments() throws {
        let json = """
        {"version":"ztp-excel/0.1","sheets":[{"name":"S","comments":[
        {"ref":"B2","author":"Alice","text":"Note here"}],"cells":[{"address":"B2","value":42}]}]}
        """
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: Data(json.utf8))
        let wb = try spec.toWorkbook()
        #expect(wb.sheets[0].comments.first?.text == "Note here")
        let data = try XLSXPackager.package(workbook: wb, styleRegistry: StyleRegistry())
        #expect(data.count > 0)
        let xml = renderXML(wb.sheets[0])
        #expect(xml.contains("<legacyDrawing r:id=\"rIdVml1\"/>"))
    }

    @Test("Conditional formatting renders data bars and color scales")
    func conditionalFormats() {
        let ws = Worksheet(name: "S", conditionalFormats: [
            ConditionalFormat(sqref: "B2:B10", kind: .dataBar, barColor: "5BA8FF"),
            ConditionalFormat(sqref: "C2:C10", kind: .colorScale, scaleColors: ["F8696B", "63BE7B"]),
        ])
        let xml = renderXML(ws)
        #expect(xml.contains("<cfRule type=\"dataBar\""))
        #expect(xml.contains("<cfRule type=\"colorScale\""))
        #expect(xml.contains("rgb=\"FF5BA8FF\""))   // 6-hex normalized to ARGB
    }
}

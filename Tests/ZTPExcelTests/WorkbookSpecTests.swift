import Testing
import Foundation
@testable import ZTPExcel

@Suite("WorkbookSpec Tests")
struct WorkbookSpecTests {

    @Test("Decode complete spec from JSON")
    func decodeSpec() throws {
        let json = """
        {
          "version": "ztp-excel/0.1",
          "workbook": { "title": "Test", "author": "Agent" },
          "sheets": [
            {
              "name": "Data",
              "cells": [
                { "address": "A1", "value": "Hello", "style": "header" },
                { "address": "B1", "value": 42 },
                { "address": "C1", "value": true },
                { "address": "D1", "formula": "SUM(B1:B10)" }
              ]
            }
          ],
          "styles": {
            "header": {
              "font": { "bold": true, "size": 14 }
            }
          }
        }
        """
        let data = Data(json.utf8)
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: data)

        #expect(spec.version == "ztp-excel/0.1")
        #expect(spec.workbook?.title == "Test")
        #expect(spec.sheets.count == 1)
        #expect(spec.sheets[0].cells.count == 4)
        #expect(spec.styles?["header"] != nil)
    }

    @Test("Convert spec to workbook")
    func toWorkbook() throws {
        let spec = WorkbookSpec(
            version: "ztp-excel/0.1",
            workbook: WorkbookMeta(title: "T"),
            sheets: [
                SheetSpec(name: "S1", cells: [
                    CellSpec(address: "A1", value: .string("hello")),
                    CellSpec(address: "B1", value: .int(42)),
                    CellSpec(address: "C1", formula: "A1&B1"),
                ])
            ]
        )

        let workbook = try spec.toWorkbook()
        #expect(workbook.title == "T")
        #expect(workbook.sheets.count == 1)
        #expect(workbook.sheets[0].cells.count == 3)
        #expect(workbook.sheets[0].cells[2].value == .formula("A1&B1"))
    }

    @Test("Invalid cell address throws")
    func invalidAddress() {
        let spec = WorkbookSpec(
            sheets: [SheetSpec(name: "S1", cells: [CellSpec(address: "INVALID")])]
        )
        #expect(throws: SpecError.self) {
            _ = try spec.toWorkbook()
        }
    }

    @Test("Style map conversion")
    func styleMap() {
        let spec = WorkbookSpec(
            styles: [
                "header": StyleSpec(font: FontStyleSpec(bold: true, size: 12)),
                "accent": StyleSpec(fill: FillStyleSpec(color: "FF0000")),
            ]
        )

        let map = spec.toStyleMap()
        #expect(map.count == 2)
        #expect(map["header"]?.font?.bold == true)
        #expect(map["accent"]?.fill?.color == "FF0000")
    }
}

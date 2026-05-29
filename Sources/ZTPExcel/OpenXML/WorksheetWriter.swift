// WorksheetWriter.swift
// ZTPExcel – Generates xl/worksheets/sheetN.xml for a Worksheet.

import Foundation

/// Produces a valid OpenXML worksheet XML document from a ``Worksheet``.
struct WorksheetWriter: Sendable {

    /// Generates the XML content for one worksheet.
    ///
    /// - Parameters:
    ///   - worksheet: The worksheet model to serialise.
    ///   - sharedStrings: The shared string table (mutated to register new strings).
    ///   - styleRegistry: The style registry for resolving style names to xf indices.
    /// - Returns: The complete XML string for `xl/worksheets/sheetN.xml`.
    static func toXML(
        worksheet: Worksheet,
        sharedStrings: inout SharedStringTable,
        styleRegistry: StyleRegistry
    ) -> String {

        // Group cells by row, sorted by row number then column.
        var rowMap: [Int: [Cell]] = [:]
        for cell in worksheet.cells {
            rowMap[cell.address.row, default: []].append(cell)
        }
        let sortedRowNumbers = rowMap.keys.sorted()

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"

        // Frozen panes (sheetViews must precede sheetData).
        if worksheet.freezeRows > 0 || worksheet.freezeColumns > 0 {
            let x = worksheet.freezeColumns
            let y = worksheet.freezeRows
            let topLeft = CellAddress(column: x + 1, row: y + 1).reference
            let activePane = (x > 0 && y > 0) ? "bottomRight" : (x > 0 ? "topRight" : "bottomLeft")
            xml += "<sheetViews><sheetView tabSelected=\"1\" workbookViewId=\"0\">"
            xml += "<pane"
            if x > 0 { xml += " xSplit=\"\(x)\"" }
            if y > 0 { xml += " ySplit=\"\(y)\"" }
            xml += " topLeftCell=\"\(topLeft)\" activePane=\"\(activePane)\" state=\"frozen\"/>"
            xml += "<selection pane=\"\(activePane)\" activeCell=\"\(topLeft)\" sqref=\"\(topLeft)\"/>"
            xml += "</sheetView></sheetViews>"
        }

        // Column widths (cols must precede sheetData).
        if !worksheet.columnWidths.isEmpty {
            xml += "<cols>"
            for cw in worksheet.columnWidths where cw.min >= 1 && cw.max >= cw.min && cw.width > 0 {
                xml += "<col min=\"\(cw.min)\" max=\"\(cw.max)\" width=\"\(formatNumber(cw.width))\" customWidth=\"1\"/>"
            }
            xml += "</cols>"
        }

        xml += "<sheetData>"

        for rowNum in sortedRowNumbers {
            guard var cells = rowMap[rowNum] else { continue }
            cells.sort { $0.address.column < $1.address.column }

            xml += "<row r=\"\(rowNum)\">"

            for cell in cells {
                let ref = cell.address.reference

                // Resolve style index. Registry IDs are 1-based; xf indices
                // in cellXfs are 0 for default, then 1…N matching registry order.
                let styleIdx: Int
                if let name = cell.styleName,
                   let resolved = styleRegistry.resolve(name: name) {
                    // The xf index equals the position in allStyles + 1
                    // (since xfId 0 is the default). Because the registry
                    // assigns IDs starting at 1 in order, we can find the
                    // positional index.
                    let allStyles = styleRegistry.allStyles
                    if let pos = allStyles.firstIndex(where: { $0.id == resolved.id }) {
                        styleIdx = pos + 1 // +1 because cellXfs[0] is default
                    } else {
                        styleIdx = 0
                    }
                } else {
                    styleIdx = 0
                }

                let sAttr = styleIdx != 0 ? " s=\"\(styleIdx)\"" : ""

                switch cell.value {
                case .string(let s):
                    let ssIdx = sharedStrings.index(for: s)
                    xml += "<c r=\"\(ref)\"\(sAttr) t=\"s\"><v>\(ssIdx)</v></c>"

                case .number(let d):
                    xml += "<c r=\"\(ref)\"\(sAttr)><v>\(formatNumber(d))</v></c>"

                case .integer(let i):
                    xml += "<c r=\"\(ref)\"\(sAttr)><v>\(i)</v></c>"

                case .boolean(let b):
                    xml += "<c r=\"\(ref)\"\(sAttr) t=\"b\"><v>\(b ? 1 : 0)</v></c>"

                case .formula(let f):
                    xml += "<c r=\"\(ref)\"\(sAttr)><f>\(XMLEscaping.escape(f))</f></c>"

                case .date(let d):
                    let serial = dateToSerial(d)
                    xml += "<c r=\"\(ref)\"\(sAttr)><v>\(formatNumber(serial))</v></c>"

                case .blank:
                    xml += "<c r=\"\(ref)\"\(sAttr)/>"
                }
            }

            xml += "</row>"
        }

        xml += "</sheetData>"

        // Merged cells (must follow sheetData).
        let validMerges = worksheet.merges.filter { $0.contains(":") }
        if !validMerges.isEmpty {
            xml += "<mergeCells count=\"\(validMerges.count)\">"
            for ref in validMerges {
                xml += "<mergeCell ref=\"\(XMLEscaping.escape(ref))\"/>"
            }
            xml += "</mergeCells>"
        }

        // Conditional formatting (data bars / color scales) — self-contained,
        // no dxf entries required. Must precede dataValidations.
        var cfPriority = 1
        for cf in worksheet.conditionalFormats {
            xml += "<conditionalFormatting sqref=\"\(XMLEscaping.escape(cf.sqref))\">"
            switch cf.kind {
            case .dataBar:
                xml += "<cfRule type=\"dataBar\" priority=\"\(cfPriority)\"><dataBar>"
                xml += "<cfvo type=\"min\"/><cfvo type=\"max\"/><color rgb=\"\(argb(cf.barColor ?? "638EC6"))\"/>"
                xml += "</dataBar></cfRule>"
            case .colorScale:
                let colors = (cf.scaleColors?.isEmpty == false) ? cf.scaleColors! : ["F8696B", "FFEB84", "63BE7B"]
                xml += "<cfRule type=\"colorScale\" priority=\"\(cfPriority)\"><colorScale>"
                if colors.count >= 3 {
                    xml += "<cfvo type=\"min\"/><cfvo type=\"percentile\" val=\"50\"/><cfvo type=\"max\"/>"
                } else {
                    xml += "<cfvo type=\"min\"/><cfvo type=\"max\"/>"
                }
                for c in colors { xml += "<color rgb=\"\(argb(c))\"/>" }
                xml += "</colorScale></cfRule>"
            }
            xml += "</conditionalFormatting>"
            cfPriority += 1
        }

        // Data validations (dropdowns / numeric ranges).
        if !worksheet.dataValidations.isEmpty {
            xml += "<dataValidations count=\"\(worksheet.dataValidations.count)\">"
            for dv in worksheet.dataValidations {
                xml += "<dataValidation type=\"\(dv.type)\""
                if dv.formula2 != nil { xml += " operator=\"between\"" }
                xml += " allowBlank=\"1\" showInputMessage=\"1\" showErrorMessage=\"1\""
                xml += " sqref=\"\(XMLEscaping.escape(dv.sqref))\">"
                xml += "<formula1>\(XMLEscaping.escape(dv.formula1))</formula1>"
                if let f2 = dv.formula2 { xml += "<formula2>\(XMLEscaping.escape(f2))</formula2>" }
                xml += "</dataValidation>"
            }
            xml += "</dataValidations>"
        }

        // Legacy drawing reference for cell comments (must be near the end).
        if !worksheet.comments.isEmpty {
            xml += "<legacyDrawing r:id=\"rIdVml1\"/>"
        }

        xml += "</worksheet>"
        return xml
    }

    /// Normalize a hex color to 8-digit ARGB (Excel wants the alpha prefix).
    private static func argb(_ hex: String) -> String {
        var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        h = h.uppercased()
        if h.count == 6 { return "FF" + h }
        if h.count == 8 { return h }
        return "FF638EC6"
    }

    // MARK: - Date serial conversion

    /// Converts a Foundation `Date` to an Excel serial date number.
    ///
    /// Excel counts days from 1900-01-01 as day 1. It also has the
    /// well-known Lotus 1-2-3 bug that treats 1900 as a leap year,
    /// adding a phantom Feb 29 1900. Dates on or after 1900-03-01
    /// need an extra +1 to stay compatible.
    private static func dateToSerial(_ date: Date) -> Double {
        // Excel epoch: 1900-01-01 00:00:00 UTC = serial 1
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var epoch = DateComponents()
        epoch.year = 1899
        epoch.month = 12
        epoch.day = 31
        epoch.hour = 0
        epoch.minute = 0
        epoch.second = 0

        guard let epochDate = cal.date(from: epoch) else { return 0 }

        let interval = date.timeIntervalSince(epochDate)
        var serial = interval / 86400.0

        // 1900 leap year bug: if the serial is >= 60 (1900-02-29 which
        // never existed), add 1.
        if serial >= 60 {
            serial += 1
        }

        return serial
    }

    /// Formats a double, avoiding unnecessary decimal places for whole numbers.
    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded(.towardZero) && !value.isNaN && !value.isInfinite {
            let intVal = Int(exactly: value.rounded(.towardZero))
            if let iv = intVal {
                return String(iv)
            }
        }
        return String(value)
    }
}

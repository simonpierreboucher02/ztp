// WorkbookWriter.swift
// ZTPExcel – Generates xl/workbook.xml and xl/_rels/workbook.xml.rels.

import Foundation

/// Produces the workbook-level XML documents for an XLSX package.
struct WorkbookWriter: Sendable {

    /// Generates `xl/workbook.xml` listing all sheet tabs.
    ///
    /// - Parameter sheetNames: The ordered sheet names.
    /// - Returns: The complete XML string.
    static func workbookXML(sheetNames: [String]) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
        xml += "<sheets>"

        for (i, name) in sheetNames.enumerated() {
            let sheetId = i + 1
            let rId = "rId\(sheetId)"
            xml += "<sheet name=\"\(XMLEscaping.escape(name))\" sheetId=\"\(sheetId)\" r:id=\"\(rId)\"/>"
        }

        xml += "</sheets>"
        xml += "</workbook>"
        return xml
    }

    /// Generates `xl/_rels/workbook.xml.rels` mapping relationship IDs
    /// to worksheet parts, styles, and shared strings.
    ///
    /// - Parameters:
    ///   - sheetCount: The number of worksheets.
    ///   - hasSharedStrings: Whether a shared string table is present.
    /// - Returns: The complete XML string.
    static func workbookRelsXML(sheetCount: Int, hasSharedStrings: Bool) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let wsType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
        let stylesType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
        let ssType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"

        var nextId = 1

        // Worksheet relationships
        for i in 1...sheetCount {
            xml += "<Relationship Id=\"rId\(nextId)\" Type=\"\(wsType)\""
            xml += " Target=\"worksheets/sheet\(i).xml\"/>"
            nextId += 1
        }

        // Styles relationship
        xml += "<Relationship Id=\"rId\(nextId)\" Type=\"\(stylesType)\""
        xml += " Target=\"styles.xml\"/>"
        nextId += 1

        // Shared strings relationship
        if hasSharedStrings {
            xml += "<Relationship Id=\"rId\(nextId)\" Type=\"\(ssType)\""
            xml += " Target=\"sharedStrings.xml\"/>"
        }

        xml += "</Relationships>"
        return xml
    }
}

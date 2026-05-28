// ContentTypes.swift
// ZTPExcel – Generates [Content_Types].xml for an XLSX package.

import Foundation

/// Produces the `[Content_Types].xml` document that lists every part
/// in the XLSX ZIP archive and its content type.
struct ContentTypesWriter: Sendable {

    /// Generates the full `[Content_Types].xml` content.
    ///
    /// - Parameters:
    ///   - sheetCount: The number of worksheets in the package.
    ///   - hasSharedStrings: Whether a shared strings part is included.
    /// - Returns: The complete XML string.
    static func toXML(sheetCount: Int, hasSharedStrings: Bool) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/content-types"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Types xmlns=\"\(ns)\">"

        // Default extensions
        xml += "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        xml += "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"

        // Workbook
        xml += "<Override PartName=\"/xl/workbook.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"

        // Worksheets
        for i in 1...sheetCount {
            xml += "<Override PartName=\"/xl/worksheets/sheet\(i).xml\""
            xml += " ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }

        // Styles
        xml += "<Override PartName=\"/xl/styles.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"

        // Shared strings
        if hasSharedStrings {
            xml += "<Override PartName=\"/xl/sharedStrings.xml\""
            xml += " ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>"
        }

        // Core properties
        xml += "<Override PartName=\"/docProps/core.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"

        // App properties
        xml += "<Override PartName=\"/docProps/app.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"

        xml += "</Types>"
        return xml
    }
}

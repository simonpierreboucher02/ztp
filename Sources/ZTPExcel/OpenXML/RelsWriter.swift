// RelsWriter.swift
// ZTPExcel – Generates the root _rels/.rels file for an XLSX package.

import Foundation

/// Produces the root relationships file that points to the workbook
/// and document properties.
struct RelsWriter: Sendable {

    /// Generates the `_rels/.rels` XML listing the top-level
    /// relationships in the XLSX package.
    ///
    /// - Returns: The complete XML string.
    static func rootRelsXML() -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let wbType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        let coreType = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
        let appType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(wbType)\" Target=\"xl/workbook.xml\"/>"
        xml += "<Relationship Id=\"rId2\" Type=\"\(coreType)\" Target=\"docProps/core.xml\"/>"
        xml += "<Relationship Id=\"rId3\" Type=\"\(appType)\" Target=\"docProps/app.xml\"/>"
        xml += "</Relationships>"
        return xml
    }
}

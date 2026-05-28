// DocxRelsWriter.swift
// ZTPDocx – Generates .rels relationship files for the DOCX archive

import Foundation

/// Produces the relationship XML files required by Office Open XML.
public struct DocxRelsWriter: Sendable {

    /// Generates `_rels/.rels` — the root relationships file that points to
    /// the main document part and the document properties.
    public static func rootRelsXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n"
        xml += "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>\n"
        xml += "  <Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>\n"
        xml += "  <Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>\n"
        xml += "</Relationships>"
        return xml
    }

    /// Generates `word/_rels/document.xml.rels` — the relationships file for
    /// the main document part.
    ///
    /// - Parameters:
    ///   - imageRelationships: Pairs of (rId, target) for each embedded image,
    ///     where `target` is the relative path within the word directory (e.g.
    ///     `media/image1.png`).
    ///   - hasNumbering: Whether the document uses bullet or numbered lists,
    ///     requiring a reference to `numbering.xml`.
    public static func documentRelsXML(
        imageRelationships: [(rId: String, target: String)],
        hasNumbering: Bool
    ) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n"

        // Styles relationship
        xml += "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>\n"

        // Numbering relationship
        if hasNumbering {
            xml += "  <Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>\n"
        }

        // Image relationships
        for rel in imageRelationships {
            let escapedTarget = DocxXMLEscaping.escape(rel.target)
            xml += "  <Relationship Id=\"\(DocxXMLEscaping.escape(rel.rId))\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"\(escapedTarget)\"/>\n"
        }

        xml += "</Relationships>"
        return xml
    }
}

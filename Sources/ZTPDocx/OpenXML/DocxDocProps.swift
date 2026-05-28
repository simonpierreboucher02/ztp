// DocxDocProps.swift
// ZTPDocx – Generates docProps/core.xml and docProps/app.xml

import Foundation

/// Produces the document property XML files for an Office Open XML package.
public struct DocxDocProps: Sendable {

    /// Generates `docProps/core.xml` with Dublin Core metadata.
    ///
    /// - Parameters:
    ///   - title: The document title (optional).
    ///   - author: The document author (optional).
    /// - Returns: A well-formed XML string.
    public static func coreXML(title: String?, author: String?) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<cp:coreProperties"
        xml += " xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\""
        xml += " xmlns:dc=\"http://purl.org/dc/elements/1.1/\""
        xml += " xmlns:dcterms=\"http://purl.org/dc/terms/\""
        xml += " xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\""
        xml += " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n"

        if let title = title, !title.isEmpty {
            xml += "  <dc:title>\(DocxXMLEscaping.escape(title))</dc:title>\n"
        }
        if let author = author, !author.isEmpty {
            xml += "  <dc:creator>\(DocxXMLEscaping.escape(author))</dc:creator>\n"
            xml += "  <cp:lastModifiedBy>\(DocxXMLEscaping.escape(author))</cp:lastModifiedBy>\n"
        }

        let now = ISO8601DateFormatter().string(from: Date())
        xml += "  <dcterms:created xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:created>\n"
        xml += "  <dcterms:modified xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:modified>\n"

        xml += "</cp:coreProperties>"
        return xml
    }

    /// Generates `docProps/app.xml` with application metadata.
    ///
    /// - Returns: A well-formed XML string.
    public static func appXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">\n"
        xml += "  <Application>ZTPDocx</Application>\n"
        xml += "  <AppVersion>1.0</AppVersion>\n"
        xml += "</Properties>"
        return xml
    }
}

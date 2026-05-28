// DocProps.swift
// ZTPExcel – Generates docProps/core.xml and docProps/app.xml.

import Foundation

/// Produces the Dublin Core document properties XML files.
struct DocPropsWriter: Sendable {

    /// Generates `docProps/core.xml` with title, author, and timestamps.
    ///
    /// - Parameters:
    ///   - title:  Optional document title.
    ///   - author: Optional document author.
    /// - Returns: The complete XML string.
    static func coreXML(title: String?, author: String?) -> String {
        let now = ISO8601DateFormatter().string(from: Date())

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<cp:coreProperties"
        xml += " xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\""
        xml += " xmlns:dc=\"http://purl.org/dc/elements/1.1/\""
        xml += " xmlns:dcterms=\"http://purl.org/dc/terms/\""
        xml += " xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\""
        xml += " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"

        if let title = title {
            xml += "<dc:title>\(XMLEscaping.escape(title))</dc:title>"
        }
        if let author = author {
            xml += "<dc:creator>\(XMLEscaping.escape(author))</dc:creator>"
            xml += "<cp:lastModifiedBy>\(XMLEscaping.escape(author))</cp:lastModifiedBy>"
        }

        xml += "<dcterms:created xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:created>"
        xml += "<dcterms:modified xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:modified>"

        xml += "</cp:coreProperties>"
        return xml
    }

    /// Generates `docProps/app.xml` with application metadata.
    ///
    /// - Returns: The complete XML string.
    static func appXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\""
        xml += " xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">"
        xml += "<Application>ZTPExcel</Application>"
        xml += "<DocSecurity>0</DocSecurity>"
        xml += "<ScaleCrop>false</ScaleCrop>"
        xml += "<LinksUpToDate>false</LinksUpToDate>"
        xml += "<SharedDoc>false</SharedDoc>"
        xml += "<HyperlinksChanged>false</HyperlinksChanged>"
        xml += "<AppVersion>1.0000</AppVersion>"
        xml += "</Properties>"
        return xml
    }
}

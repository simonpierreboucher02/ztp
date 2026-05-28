// DocxContentTypes.swift
// ZTPDocx – Generates [Content_Types].xml for the DOCX archive

import Foundation

/// Produces the `[Content_Types].xml` file required at the root of every
/// Office Open XML package.
public struct DocxContentTypes: Sendable {

    /// Generates the XML string for `[Content_Types].xml`.
    ///
    /// - Parameters:
    ///   - hasImages: Whether the document contains any image elements.
    ///   - imageExtensions: The set of lowercase file extensions (e.g. "png", "jpeg")
    ///     present among the document images.
    /// - Returns: A well-formed XML string.
    public static func toXML(hasImages: Bool, imageExtensions: Set<String>) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n"

        // Default content types for standard parts
        xml += "  <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n"
        xml += "  <Default Extension=\"xml\" ContentType=\"application/xml\"/>\n"

        // Image content types
        if hasImages {
            let sorted = imageExtensions.sorted()
            for ext in sorted {
                let mime: String
                switch ext.lowercased() {
                case "png":
                    mime = "image/png"
                case "jpg", "jpeg":
                    mime = "image/jpeg"
                case "gif":
                    mime = "image/gif"
                case "bmp":
                    mime = "image/bmp"
                case "tiff", "tif":
                    mime = "image/tiff"
                case "svg":
                    mime = "image/svg+xml"
                default:
                    mime = "application/octet-stream"
                }
                xml += "  <Default Extension=\"\(DocxXMLEscaping.escape(ext))\" ContentType=\"\(mime)\"/>\n"
            }
        }

        // Override content types for specific parts
        xml += "  <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>\n"
        xml += "  <Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>\n"
        xml += "  <Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>\n"
        xml += "  <Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>\n"
        xml += "  <Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>\n"

        xml += "</Types>"
        return xml
    }
}

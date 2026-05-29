// HeaderFooterWriter.swift
// ZTPDocx – Generates word/header1.xml and word/footer1.xml parts

import Foundation

/// Produces header and footer parts for a DOCX archive. The schema already
/// accepted `header`/`footer` text per section but it was previously dropped on
/// the floor; these parts make it render.
public struct HeaderFooterWriter: Sendable {

    private static let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"

    private static func roots(_ tag: String) -> (open: String, close: String) {
        let open = "<w:\(tag)"
            + " xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\""
            + " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n"
        return (open, "</w:\(tag)>")
    }

    /// A header part containing a single centered paragraph of text.
    public static func headerXML(text: String) -> String {
        let r = roots("hdr")
        return header + r.open + paragraph(text: text, centered: true) + r.close
    }

    /// A footer part. Optionally appends a centered "Page N" field.
    public static func footerXML(text: String?, pageNumbers: Bool) -> String {
        let r = roots("ftr")
        var body = ""
        if let text, !text.isEmpty {
            body += paragraph(text: text, centered: true, pageField: pageNumbers && (text.range(of: "{page}") == nil))
        } else if pageNumbers {
            body += paragraph(text: "", centered: true, pageField: true)
        } else {
            body += paragraph(text: "", centered: true)
        }
        return header + r.open + body + r.close
    }

    // MARK: - Paragraph

    /// Render a paragraph. Supports a `{page}` token (replaced by a PAGE field)
    /// and an optional trailing PAGE field.
    private static func paragraph(text: String, centered: Bool, pageField: Bool = false) -> String {
        var p = "  <w:p>\n"
        if centered {
            p += "    <w:pPr><w:jc w:val=\"center\"/></w:pPr>\n"
        }
        // Split on the {page} token so a PAGE field can be inlined.
        let segments = text.components(separatedBy: "{page}")
        for (i, seg) in segments.enumerated() {
            if !seg.isEmpty {
                p += "    <w:r><w:t xml:space=\"preserve\">\(DocxXMLEscaping.escape(seg))</w:t></w:r>\n"
            }
            if i < segments.count - 1 {
                p += pageNumberRun()
            }
        }
        if pageField {
            p += pageNumberRun()
        }
        p += "  </w:p>\n"
        return p
    }

    private static func pageNumberRun() -> String {
        "    <w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>\n"
            + "    <w:r><w:instrText xml:space=\"preserve\"> PAGE </w:instrText></w:r>\n"
            + "    <w:r><w:fldChar w:fldCharType=\"end\"/></w:r>\n"
    }
}

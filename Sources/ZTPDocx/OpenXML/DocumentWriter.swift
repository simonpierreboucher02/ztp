// DocumentWriter.swift
// ZTPDocx – Generates word/document.xml (the main content file)

import Foundation

/// Produces `word/document.xml`, the primary content part of a DOCX archive.
///
/// Renders every element from every section of a ``DocxDocument`` into
/// Office Open XML paragraph, table, and drawing markup.
public struct DocumentWriter: Sendable {

    /// Generates the complete `document.xml` content.
    ///
    /// - Parameters:
    ///   - document: The document model to render.
    ///   - styleRegistry: The style registry for resolving named styles.
    ///   - imageRelationships: A mapping from image file path to its
    ///     relationship ID (e.g. `"rId4"`).
    /// - Returns: A well-formed XML string.
    public static func toXML(
        document: DocxDocument,
        styleRegistry: DocxStyleRegistry,
        imageRelationships: [String: String],
        headerRelId: String? = nil,
        footerRelId: String? = nil,
        hyperlinkRelationships: [String: String] = [:]
    ) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<w:document"
        xml += " xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        xml += " xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\""
        xml += " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">\n"
        xml += "  <w:body>\n"

        var imageCounter = 0

        for section in document.sections {
            for element in section.elements {
                xml += renderElement(
                    element,
                    styleRegistry: styleRegistry,
                    imageRelationships: imageRelationships,
                    imageCounter: &imageCounter,
                    hyperlinks: hyperlinkRelationships
                )
            }
        }

        if headerRelId != nil || footerRelId != nil {
            xml += "    <w:sectPr>\n"
            if let h = headerRelId {
                xml += "      <w:headerReference w:type=\"default\" r:id=\"\(h)\"/>\n"
            }
            if let f = footerRelId {
                xml += "      <w:footerReference w:type=\"default\" r:id=\"\(f)\"/>\n"
            }
            xml += "    </w:sectPr>\n"
        } else {
            xml += "    <w:sectPr/>\n"
        }
        xml += "  </w:body>\n"
        xml += "</w:document>"
        return xml
    }

    // MARK: - Element Rendering

    private static func renderElement(
        _ element: DocxElement,
        styleRegistry: DocxStyleRegistry,
        imageRelationships: [String: String],
        imageCounter: inout Int,
        hyperlinks: [String: String] = [:]
    ) -> String {
        switch element {
        case let .heading(level, text, style):
            return renderHeading(level: level, text: text, style: style, styleRegistry: styleRegistry)

        case let .paragraph(runs, style, alignment):
            return renderParagraph(runs: runs, style: style, alignment: alignment, styleRegistry: styleRegistry, hyperlinks: hyperlinks)

        case let .bulletList(items):
            return renderListItems(items, numId: "1")

        case let .numberedList(items):
            return renderListItems(items, numId: "2")

        case let .table(docxTable):
            return renderTable(docxTable)

        case let .image(docxImage):
            imageCounter += 1
            return renderImage(docxImage, imageRelationships: imageRelationships, index: imageCounter)

        case .pageBreak:
            return renderPageBreak()

        case .horizontalRule:
            return renderHorizontalRule()
        }
    }

    // MARK: - Heading

    private static func renderHeading(
        level: Int,
        text: String,
        style: String?,
        styleRegistry: DocxStyleRegistry
    ) -> String {
        let clampedLevel = max(1, min(level, 9))
        let escapedText = DocxXMLEscaping.escape(text)

        var xml = "    <w:p>\n"
        xml += "      <w:pPr><w:pStyle w:val=\"Heading\(clampedLevel)\"/></w:pPr>\n"

        // If a named style is referenced, apply its run properties
        var rPr = ""
        if let styleName = style, let resolved = styleRegistry.resolve(name: styleName) {
            rPr = buildRunPropertiesFromStyle(resolved)
        }

        if rPr.isEmpty {
            xml += "      <w:r><w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>\n"
        } else {
            xml += "      <w:r>\(rPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>\n"
        }

        xml += "    </w:p>\n"
        return xml
    }

    // MARK: - Paragraph

    private static func renderParagraph(
        runs: [DocxRun],
        style: String?,
        alignment: ParagraphAlignment?,
        styleRegistry: DocxStyleRegistry,
        hyperlinks: [String: String] = [:]
    ) -> String {
        var xml = "    <w:p>\n"

        // Paragraph properties
        let resolvedStyle = style.flatMap { styleRegistry.resolve(name: $0) }
        let effectiveAlignment = alignment ?? resolvedStyle?.paragraph?.alignment

        var hasPPr = false
        if style != nil || effectiveAlignment != nil {
            hasPPr = true
            xml += "      <w:pPr>\n"
            if let styleName = style {
                xml += "        <w:pStyle w:val=\"\(DocxXMLEscaping.escape(styleName))\"/>\n"
            }
            if let align = effectiveAlignment {
                xml += "        <w:jc w:val=\"\(align.rawValue)\"/>\n"
            }
            xml += "      </w:pPr>\n"
        }

        // Runs
        for run in runs {
            xml += renderRun(run, resolvedStyle: hasPPr ? nil : resolvedStyle, hyperlinks: hyperlinks)
        }

        xml += "    </w:p>\n"
        return xml
    }

    // MARK: - Run

    private static func renderRun(_ run: DocxRun, resolvedStyle: DocxStyle?, hyperlinks: [String: String] = [:]) -> String {
        let escapedText = DocxXMLEscaping.escape(run.text)

        var rPr = ""
        var hasFormatting = false

        var parts: [String] = []

        // Bold
        if run.bold == true {
            parts.append("<w:b/>")
            hasFormatting = true
        }
        // Italic
        if run.italic == true {
            parts.append("<w:i/>")
            hasFormatting = true
        }
        // Underline
        if run.underline == true {
            parts.append("<w:u w:val=\"single\"/>")
            hasFormatting = true
        }
        // Font size (points to half-points)
        if let fontSize = run.fontSize {
            let halfPoints = Int(fontSize * 2.0)
            parts.append("<w:sz w:val=\"\(halfPoints)\"/>")
            hasFormatting = true
        }
        // Font family
        if let fontFamily = run.fontFamily {
            let escapedFamily = DocxXMLEscaping.escape(fontFamily)
            parts.append("<w:rFonts w:ascii=\"\(escapedFamily)\"/>")
            hasFormatting = true
        }
        // Color
        if let color = run.color {
            parts.append("<w:color w:val=\"\(DocxXMLEscaping.escape(color))\"/>")
            hasFormatting = true
        }

        // Hyperlink runs get the Hyperlink character style (blue + underline)
        // unless the run already specifies a color.
        let isLink = run.link != nil && hyperlinks[run.link!] != nil
        if isLink {
            if run.color == nil { parts.append("<w:color w:val=\"0563C1\"/>") }
            if run.underline != true { parts.append("<w:u w:val=\"single\"/>") }
            hasFormatting = true
        }

        if hasFormatting {
            rPr = "<w:rPr>" + parts.joined() + "</w:rPr>"
        }

        let runXML: String
        if rPr.isEmpty {
            runXML = "<w:r><w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"
        } else {
            runXML = "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"
        }

        if isLink, let rId = hyperlinks[run.link!] {
            return "      <w:hyperlink r:id=\"\(DocxXMLEscaping.escape(rId))\">\(runXML)</w:hyperlink>\n"
        }
        return "      \(runXML)\n"
    }

    // MARK: - List Items

    private static func renderListItems(_ items: [DocxListItem], numId: String) -> String {
        var xml = ""
        for item in items {
            let escapedItem = DocxXMLEscaping.escape(item.text)
            let ilvl = max(0, min(item.level, 8))
            xml += "    <w:p>\n"
            xml += "      <w:pPr>\n"
            xml += "        <w:pStyle w:val=\"ListParagraph\"/>\n"
            xml += "        <w:numPr><w:ilvl w:val=\"\(ilvl)\"/><w:numId w:val=\"\(numId)\"/></w:numPr>\n"
            xml += "      </w:pPr>\n"
            xml += "      <w:r><w:t xml:space=\"preserve\">\(escapedItem)</w:t></w:r>\n"
            xml += "    </w:p>\n"
        }
        return xml
    }

    // MARK: - Table

    private static func renderTable(_ table: DocxTable) -> String {
        let styleName = table.style ?? "TableGrid"
        var xml = "    <w:tbl>\n"

        // Table properties
        xml += "      <w:tblPr>\n"
        xml += "        <w:tblStyle w:val=\"\(DocxXMLEscaping.escape(styleName))\"/>\n"
        xml += "        <w:tblW w:w=\"0\" w:type=\"auto\"/>\n"
        xml += "        <w:tblBorders>\n"
        for border in ["top", "left", "bottom", "right", "insideH", "insideV"] {
            xml += "          <w:\(border) w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        }
        xml += "        </w:tblBorders>\n"
        xml += "      </w:tblPr>\n"

        // Column widths (grid)
        if let widths = table.columnWidths {
            xml += "      <w:tblGrid>\n"
            for width in widths {
                xml += "        <w:gridCol w:w=\"\(width)\"/>\n"
            }
            xml += "      </w:tblGrid>\n"
        }

        // Header row
        if let headers = table.headers {
            xml += "      <w:tr>\n"
            for header in headers {
                let escapedHeader = DocxXMLEscaping.escape(header)
                xml += "        <w:tc>\n"
                xml += "          <w:tcPr><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"D9E2F3\"/></w:tcPr>\n"
                xml += "          <w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>\n"
                xml += "            <w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">\(escapedHeader)</w:t></w:r>\n"
                xml += "          </w:p>\n"
                xml += "        </w:tc>\n"
            }
            xml += "      </w:tr>\n"
        }

        // Data rows
        for row in table.rows {
            xml += "      <w:tr>\n"
            for cell in row {
                let escapedCell = DocxXMLEscaping.escape(cell)
                xml += "        <w:tc>\n"
                xml += "          <w:p><w:r><w:t xml:space=\"preserve\">\(escapedCell)</w:t></w:r></w:p>\n"
                xml += "        </w:tc>\n"
            }
            xml += "      </w:tr>\n"
        }

        xml += "    </w:tbl>\n"
        return xml
    }

    // MARK: - Image

    private static func renderImage(
        _ image: DocxImage,
        imageRelationships: [String: String],
        index: Int
    ) -> String {
        guard let rId = imageRelationships[image.path] else {
            // If no relationship found, render as a placeholder paragraph
            return "    <w:p><w:r><w:t>[Image: \(DocxXMLEscaping.escape(image.path))]</w:t></w:r></w:p>\n"
        }

        let emuPerPoint = 12700
        let widthPt = image.width ?? 400
        let heightPt = image.height ?? 300
        let widthEMU = widthPt * emuPerPoint
        let heightEMU = heightPt * emuPerPoint

        let imageName = (image.path as NSString).lastPathComponent
        let escapedName = DocxXMLEscaping.escape(imageName)
        let escapedRId = DocxXMLEscaping.escape(rId)

        var xml = "    <w:p>\n"
        xml += "      <w:r>\n"
        xml += "        <w:drawing>\n"
        xml += "          <wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">\n"
        xml += "            <wp:extent cx=\"\(widthEMU)\" cy=\"\(heightEMU)\"/>\n"
        xml += "            <wp:docPr id=\"\(index)\" name=\"Image\(index)\"/>\n"
        xml += "            <a:graphic>\n"
        xml += "              <a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">\n"
        xml += "                <pic:pic>\n"
        xml += "                  <pic:nvPicPr>\n"
        xml += "                    <pic:cNvPr id=\"\(index)\" name=\"\(escapedName)\"/>\n"
        xml += "                    <pic:cNvPicPr/>\n"
        xml += "                  </pic:nvPicPr>\n"
        xml += "                  <pic:blipFill>\n"
        xml += "                    <a:blip r:embed=\"\(escapedRId)\"/>\n"
        xml += "                    <a:stretch><a:fillRect/></a:stretch>\n"
        xml += "                  </pic:blipFill>\n"
        xml += "                  <pic:spPr>\n"
        xml += "                    <a:xfrm>\n"
        xml += "                      <a:off x=\"0\" y=\"0\"/>\n"
        xml += "                      <a:ext cx=\"\(widthEMU)\" cy=\"\(heightEMU)\"/>\n"
        xml += "                    </a:xfrm>\n"
        xml += "                    <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\n"
        xml += "                  </pic:spPr>\n"
        xml += "                </pic:pic>\n"
        xml += "              </a:graphicData>\n"
        xml += "            </a:graphic>\n"
        xml += "          </wp:inline>\n"
        xml += "        </w:drawing>\n"
        xml += "      </w:r>\n"
        xml += "    </w:p>\n"

        // Caption paragraph (if present)
        if let caption = image.caption, !caption.isEmpty {
            let escapedCaption = DocxXMLEscaping.escape(caption)
            xml += "    <w:p>\n"
            xml += "      <w:pPr><w:jc w:val=\"center\"/></w:pPr>\n"
            xml += "      <w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">\(escapedCaption)</w:t></w:r>\n"
            xml += "    </w:p>\n"
        }

        return xml
    }

    // MARK: - Page Break

    private static func renderPageBreak() -> String {
        return "    <w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>\n"
    }

    // MARK: - Horizontal Rule

    private static func renderHorizontalRule() -> String {
        return "    <w:p><w:pPr><w:pBdr><w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"1\" w:color=\"auto\"/></w:pBdr></w:pPr></w:p>\n"
    }

    // MARK: - Helpers

    /// Builds `<w:rPr>` from a resolved style (font properties only).
    private static func buildRunPropertiesFromStyle(_ style: DocxStyle) -> String {
        guard let font = style.font else { return "" }

        var parts: [String] = []
        if font.bold == true { parts.append("<w:b/>") }
        if font.italic == true { parts.append("<w:i/>") }
        if font.underline == true { parts.append("<w:u w:val=\"single\"/>") }
        if let size = font.size {
            let halfPoints = Int(size * 2.0)
            parts.append("<w:sz w:val=\"\(halfPoints)\"/>")
        }
        if let family = font.family {
            parts.append("<w:rFonts w:ascii=\"\(DocxXMLEscaping.escape(family))\"/>")
        }
        if let color = font.color {
            parts.append("<w:color w:val=\"\(DocxXMLEscaping.escape(color))\"/>")
        }

        if parts.isEmpty { return "" }
        return "<w:rPr>" + parts.joined() + "</w:rPr>"
    }
}

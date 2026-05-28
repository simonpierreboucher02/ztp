// DocxStylesWriter.swift
// ZTPDocx – Generates word/styles.xml for the DOCX archive

import Foundation

/// Produces `word/styles.xml` containing default styles, heading styles,
/// list styles, table styles, and any custom styles from the registry.
public struct DocxStylesWriter: Sendable {

    /// Generates the full styles XML.
    ///
    /// Includes:
    /// - Default document run/paragraph properties
    /// - Normal paragraph style
    /// - Heading1 through Heading9
    /// - ListParagraph for bullet/numbered lists
    /// - TableGrid table style
    /// - Custom styles from the registry
    ///
    /// - Parameter registry: The style registry containing user-defined styles.
    /// - Returns: A well-formed XML string.
    public static func toXML(registry: DocxStyleRegistry) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<w:styles"
        xml += " xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n"

        // --- Document defaults ---
        xml += "  <w:docDefaults>\n"
        xml += "    <w:rPrDefault>\n"
        xml += "      <w:rPr>\n"
        xml += "        <w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:cs=\"Calibri\"/>\n"
        xml += "        <w:sz w:val=\"22\"/>\n"  // 11pt default
        xml += "        <w:szCs w:val=\"22\"/>\n"
        xml += "        <w:lang w:val=\"en-US\"/>\n"
        xml += "      </w:rPr>\n"
        xml += "    </w:rPrDefault>\n"
        xml += "    <w:pPrDefault>\n"
        xml += "      <w:pPr>\n"
        xml += "        <w:spacing w:after=\"160\" w:line=\"259\" w:lineRule=\"auto\"/>\n"
        xml += "      </w:pPr>\n"
        xml += "    </w:pPrDefault>\n"
        xml += "  </w:docDefaults>\n"

        // --- Normal style ---
        xml += "  <w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\">\n"
        xml += "    <w:name w:val=\"Normal\"/>\n"
        xml += "    <w:qFormat/>\n"
        xml += "  </w:style>\n"

        // --- Heading styles (1-9) ---
        let headingSizes: [Int] = [32, 26, 24, 22, 22, 20, 20, 20, 20]  // half-points
        for level in 1...9 {
            let size = headingSizes[level - 1]
            xml += "  <w:style w:type=\"paragraph\" w:styleId=\"Heading\(level)\">\n"
            xml += "    <w:name w:val=\"heading \(level)\"/>\n"
            xml += "    <w:basedOn w:val=\"Normal\"/>\n"
            xml += "    <w:next w:val=\"Normal\"/>\n"
            xml += "    <w:qFormat/>\n"
            xml += "    <w:pPr>\n"
            xml += "      <w:keepNext/>\n"
            xml += "      <w:keepLines/>\n"
            xml += "      <w:spacing w:before=\"240\" w:after=\"80\"/>\n"
            xml += "      <w:outlineLvl w:val=\"\(level - 1)\"/>\n"
            xml += "    </w:pPr>\n"
            xml += "    <w:rPr>\n"
            xml += "      <w:b/>\n"
            xml += "      <w:bCs/>\n"
            xml += "      <w:sz w:val=\"\(size)\"/>\n"
            xml += "      <w:szCs w:val=\"\(size)\"/>\n"
            if level <= 2 {
                xml += "      <w:color w:val=\"2F5496\"/>\n"
            }
            xml += "    </w:rPr>\n"
            xml += "  </w:style>\n"
        }

        // --- ListParagraph style ---
        xml += "  <w:style w:type=\"paragraph\" w:styleId=\"ListParagraph\">\n"
        xml += "    <w:name w:val=\"List Paragraph\"/>\n"
        xml += "    <w:basedOn w:val=\"Normal\"/>\n"
        xml += "    <w:qFormat/>\n"
        xml += "    <w:pPr>\n"
        xml += "      <w:ind w:left=\"720\"/>\n"
        xml += "      <w:contextualSpacing/>\n"
        xml += "    </w:pPr>\n"
        xml += "  </w:style>\n"

        // --- TableGrid table style ---
        xml += "  <w:style w:type=\"table\" w:styleId=\"TableGrid\">\n"
        xml += "    <w:name w:val=\"Table Grid\"/>\n"
        xml += "    <w:basedOn w:val=\"TableNormal\"/>\n"
        xml += "    <w:tblPr>\n"
        xml += "      <w:tblBorders>\n"
        xml += "        <w:top w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "        <w:left w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "        <w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "        <w:right w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "        <w:insideH w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "        <w:insideV w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>\n"
        xml += "      </w:tblBorders>\n"
        xml += "    </w:tblPr>\n"
        xml += "  </w:style>\n"

        // --- TableNormal base style ---
        xml += "  <w:style w:type=\"table\" w:default=\"1\" w:styleId=\"TableNormal\">\n"
        xml += "    <w:name w:val=\"Normal Table\"/>\n"
        xml += "    <w:tblPr>\n"
        xml += "      <w:tblInd w:w=\"0\" w:type=\"dxa\"/>\n"
        xml += "      <w:tblCellMar>\n"
        xml += "        <w:top w:w=\"0\" w:type=\"dxa\"/>\n"
        xml += "        <w:left w:w=\"108\" w:type=\"dxa\"/>\n"
        xml += "        <w:bottom w:w=\"0\" w:type=\"dxa\"/>\n"
        xml += "        <w:right w:w=\"108\" w:type=\"dxa\"/>\n"
        xml += "      </w:tblCellMar>\n"
        xml += "    </w:tblPr>\n"
        xml += "  </w:style>\n"

        // --- Custom registered styles ---
        for (name, style) in registry.allStyles {
            let escapedName = DocxXMLEscaping.escape(name)
            xml += "  <w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"\(escapedName)\">\n"
            xml += "    <w:name w:val=\"\(escapedName)\"/>\n"
            xml += "    <w:basedOn w:val=\"Normal\"/>\n"

            // Paragraph properties
            if let para = style.paragraph {
                xml += "    <w:pPr>\n"
                if let alignment = para.alignment {
                    xml += "      <w:jc w:val=\"\(alignment.rawValue)\"/>\n"
                }
                let hasBefore = para.spacingBefore != nil
                let hasAfter = para.spacingAfter != nil
                let hasLine = para.lineSpacing != nil
                if hasBefore || hasAfter || hasLine {
                    var spacingAttrs = ""
                    if let before = para.spacingBefore {
                        spacingAttrs += " w:before=\"\(before * 20)\""  // points to twips
                    }
                    if let after = para.spacingAfter {
                        spacingAttrs += " w:after=\"\(after * 20)\""
                    }
                    if let line = para.lineSpacing {
                        let lineVal = Int(line * 240.0)  // line spacing in 240ths of a line
                        spacingAttrs += " w:line=\"\(lineVal)\" w:lineRule=\"auto\""
                    }
                    xml += "      <w:spacing\(spacingAttrs)/>\n"
                }
                xml += "    </w:pPr>\n"
            }

            // Run properties
            if let font = style.font {
                xml += "    <w:rPr>\n"
                if font.bold == true {
                    xml += "      <w:b/>\n"
                    xml += "      <w:bCs/>\n"
                }
                if font.italic == true {
                    xml += "      <w:i/>\n"
                    xml += "      <w:iCs/>\n"
                }
                if font.underline == true {
                    xml += "      <w:u w:val=\"single\"/>\n"
                }
                if let size = font.size {
                    let halfPoints = Int(size * 2.0)
                    xml += "      <w:sz w:val=\"\(halfPoints)\"/>\n"
                    xml += "      <w:szCs w:val=\"\(halfPoints)\"/>\n"
                }
                if let family = font.family {
                    let escapedFamily = DocxXMLEscaping.escape(family)
                    xml += "      <w:rFonts w:ascii=\"\(escapedFamily)\" w:hAnsi=\"\(escapedFamily)\"/>\n"
                }
                if let color = font.color {
                    xml += "      <w:color w:val=\"\(DocxXMLEscaping.escape(color))\"/>\n"
                }
                xml += "    </w:rPr>\n"
            }

            xml += "  </w:style>\n"
        }

        xml += "</w:styles>"
        return xml
    }
}

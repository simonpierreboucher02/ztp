// NumberingWriter.swift
// ZTPDocx – Generates word/numbering.xml for bullet and numbered lists

import Foundation

/// Produces `word/numbering.xml` with abstract numbering definitions for
/// bullet lists and decimal numbered lists.
public struct NumberingWriter: Sendable {

    /// Generates the numbering definitions XML.
    ///
    /// Defines two abstract numbering schemes:
    /// - `abstractNumId="0"` — bullets (Unicode bullet character U+2022)
    /// - `abstractNumId="1"` — decimal numbered list
    ///
    /// And two concrete references:
    /// - `numId="1"` → `abstractNumId="0"` (bullets)
    /// - `numId="2"` → `abstractNumId="1"` (numbered)
    public static func toXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<w:numbering"
        xml += " xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">\n"

        // Abstract numbering 0: bullet list
        xml += "  <w:abstractNum w:abstractNumId=\"0\">\n"
        xml += "    <w:multiLevelType w:val=\"hybridMultilevel\"/>\n"
        for level in 0..<9 {
            let indent = (level + 1) * 720
            let hanging = 360
            xml += "    <w:lvl w:ilvl=\"\(level)\">\n"
            xml += "      <w:start w:val=\"1\"/>\n"
            xml += "      <w:numFmt w:val=\"bullet\"/>\n"
            xml += "      <w:lvlText w:val=\"\u{2022}\"/>\n"
            xml += "      <w:lvlJc w:val=\"left\"/>\n"
            xml += "      <w:pPr>\n"
            xml += "        <w:ind w:left=\"\(indent)\" w:hanging=\"\(hanging)\"/>\n"
            xml += "      </w:pPr>\n"
            xml += "      <w:rPr>\n"
            xml += "        <w:rFonts w:ascii=\"Symbol\" w:hAnsi=\"Symbol\" w:hint=\"default\"/>\n"
            xml += "      </w:rPr>\n"
            xml += "    </w:lvl>\n"
        }
        xml += "  </w:abstractNum>\n"

        // Abstract numbering 1: decimal numbered list
        xml += "  <w:abstractNum w:abstractNumId=\"1\">\n"
        xml += "    <w:multiLevelType w:val=\"hybridMultilevel\"/>\n"
        for level in 0..<9 {
            let indent = (level + 1) * 720
            let hanging = 360
            xml += "    <w:lvl w:ilvl=\"\(level)\">\n"
            xml += "      <w:start w:val=\"1\"/>\n"
            xml += "      <w:numFmt w:val=\"decimal\"/>\n"
            xml += "      <w:lvlText w:val=\"%\(level + 1).\"/>\n"
            xml += "      <w:lvlJc w:val=\"left\"/>\n"
            xml += "      <w:pPr>\n"
            xml += "        <w:ind w:left=\"\(indent)\" w:hanging=\"\(hanging)\"/>\n"
            xml += "      </w:pPr>\n"
            xml += "    </w:lvl>\n"
        }
        xml += "  </w:abstractNum>\n"

        // Concrete numbering references
        xml += "  <w:num w:numId=\"1\">\n"
        xml += "    <w:abstractNumId w:val=\"0\"/>\n"
        xml += "  </w:num>\n"
        xml += "  <w:num w:numId=\"2\">\n"
        xml += "    <w:abstractNumId w:val=\"1\"/>\n"
        xml += "  </w:num>\n"

        xml += "</w:numbering>"
        return xml
    }
}

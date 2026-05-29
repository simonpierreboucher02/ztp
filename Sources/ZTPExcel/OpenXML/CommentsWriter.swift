// CommentsWriter.swift
// ZTPExcel – Generates cell comment parts (comments{N}.xml + legacy VML drawing)

import Foundation

/// Produces the parts required for Excel cell comments: the comment list and
/// the legacy VML drawing that positions each note box (Excel needs both).
public struct CommentsWriter: Sendable {

    /// `xl/comments{N}.xml` — authors + comment text per cell.
    public static func commentsXML(_ comments: [CellComment]) -> String {
        let authors = Array(Set(comments.map(\.author))).sorted()
        let authorIndex = Dictionary(uniqueKeysWithValues: authors.enumerated().map { ($1, $0) })

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        xml += "<authors>"
        for a in authors { xml += "<author>\(XMLEscaping.escape(a))</author>" }
        xml += "</authors><commentList>"
        for c in comments {
            let aid = authorIndex[c.author] ?? 0
            xml += "<comment ref=\"\(XMLEscaping.escape(c.ref))\" authorId=\"\(aid)\"><text>"
            xml += "<r><rPr><b/><sz val=\"9\"/><color indexed=\"81\"/><rFont val=\"Tahoma\"/></rPr>"
            xml += "<t xml:space=\"preserve\">\(XMLEscaping.escape(c.author)):\u{0A}</t></r>"
            xml += "<r><rPr><sz val=\"9\"/><color indexed=\"81\"/><rFont val=\"Tahoma\"/></rPr>"
            xml += "<t xml:space=\"preserve\">\(XMLEscaping.escape(c.text))</t></r>"
            xml += "</text></comment>"
        }
        xml += "</commentList></comments>"
        return xml
    }

    /// `xl/drawings/vmlDrawing{N}.vml` — one note box per comment.
    public static func vmlXML(_ comments: [CellComment]) -> String {
        var xml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\""
        xml += " xmlns:o=\"urn:schemas-microsoft-com:office:office\""
        xml += " xmlns:x=\"urn:schemas-microsoft-com:office:excel\">"
        xml += "<o:shapelayout v:ext=\"edit\"><o:idmap v:ext=\"edit\" data=\"1\"/></o:shapelayout>"
        xml += "<v:shapetype id=\"_x0000_t202\" coordsize=\"21600,21600\" o:spt=\"202\""
        xml += " path=\"m,l,21600r21600,l21600,xe\"><v:stroke joinstyle=\"miter\"/>"
        xml += "<v:path gradientshapeok=\"t\" o:connecttype=\"rect\"/></v:shapetype>"

        for (i, c) in comments.enumerated() {
            let (col, row) = Self.colRow(c.ref)   // 0-based
            let shapeId = 1025 + i
            xml += "<v:shape id=\"_x0000_s\(shapeId)\" type=\"#_x0000_t202\""
            xml += " style=\"position:absolute;margin-left:60pt;margin-top:1.5pt;width:144pt;height:72pt;"
            xml += "z-index:\(i + 1);visibility:hidden\" fillcolor=\"#ffffe1\" o:insetmode=\"auto\">"
            xml += "<v:fill color2=\"#ffffe1\"/><v:shadow on=\"t\" color=\"black\" obscured=\"t\"/>"
            xml += "<v:path o:connecttype=\"none\"/>"
            xml += "<v:textbox style=\"mso-direction-alt:auto\"><div style=\"text-align:left\"></div></v:textbox>"
            xml += "<x:ClientData ObjectType=\"Note\"><x:MoveWithCells/><x:SizeWithCells/>"
            xml += "<x:Anchor>\(col + 1), 15, \(row), 2, \(col + 3), 15, \(row + 4), 4</x:Anchor>"
            xml += "<x:AutoFill>False</x:AutoFill><x:Row>\(row)</x:Row><x:Column>\(col)</x:Column>"
            xml += "</x:ClientData></v:shape>"
        }
        xml += "</xml>"
        return xml
    }

    /// `xl/worksheets/_rels/sheet{N}.xml.rels` linking the comment + VML parts.
    public static func sheetRelsXML(sheetNumber: Int) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let vmlType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing"
        let commentsType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"
        xml += "<Relationship Id=\"rIdVml1\" Type=\"\(vmlType)\" Target=\"../drawings/vmlDrawing\(sheetNumber).vml\"/>"
        xml += "<Relationship Id=\"rIdCmt1\" Type=\"\(commentsType)\" Target=\"../comments\(sheetNumber).xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    /// Parse an A1 ref into 0-based (column, row).
    static func colRow(_ ref: String) -> (col: Int, row: Int) {
        if let addr = CellAddress(string: ref) {
            return (addr.column - 1, addr.row - 1)
        }
        return (0, 0)
    }
}

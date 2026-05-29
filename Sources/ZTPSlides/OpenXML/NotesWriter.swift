// NotesWriter.swift
// ZTPSlides – Generates speaker-notes parts (notesSlideN.xml + notesMaster1.xml)

import Foundation

/// Produces the notes parts for a PPTX. The schema accepted a `notes` field per
/// slide but it was previously dropped; these parts make speaker notes render
/// in PowerPoint/Keynote.
public struct NotesWriter: Sendable {

    private static let aNS = "http://schemas.openxmlformats.org/drawingml/2006/main"
    private static let pNS = "http://schemas.openxmlformats.org/presentationml/2006/main"
    private static let rNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let relsNS = "http://schemas.openxmlformats.org/package/2006/relationships"

    // MARK: - notesSlideN.xml

    public static func notesSlideXML(text: String) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:notes xmlns:a=\"\(aNS)\" xmlns:r=\"\(rNS)\" xmlns:p=\"\(pNS)\">"
        xml += "<p:cSld><p:spTree>"
        xml += "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        xml += "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>"
        xml += "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        // Body placeholder carrying the notes text.
        xml += "<p:sp>"
        xml += "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Notes Placeholder 1\"/>"
        xml += "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>"
        xml += "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr></p:nvSpPr>"
        xml += "<p:spPr/>"
        xml += "<p:txBody><a:bodyPr/><a:lstStyle/>"
        for line in text.components(separatedBy: "\n") {
            xml += "<a:p><a:r><a:t>\(SlidesXMLEscaping.escape(line))</a:t></a:r></a:p>"
        }
        xml += "</p:txBody></p:sp>"
        xml += "</p:spTree></p:cSld>"
        xml += "<p:clrMapOvr><a:overrideClrMapping bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\""
        xml += " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\""
        xml += " accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/></p:clrMapOvr>"
        xml += "</p:notes>"
        return xml
    }

    /// `ppt/notesSlides/_rels/notesSlideN.xml.rels` — references the notes
    /// master and the owning slide.
    public static func notesSlideRelsXML(slideNumber: Int) -> String {
        let notesMasterType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster"
        let slideType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(relsNS)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(notesMasterType)\" Target=\"../notesMasters/notesMaster1.xml\"/>"
        xml += "<Relationship Id=\"rId2\" Type=\"\(slideType)\" Target=\"../slides/slide\(slideNumber).xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    // MARK: - notesMaster1.xml

    public static func notesMasterXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:notesMaster xmlns:a=\"\(aNS)\" xmlns:r=\"\(rNS)\" xmlns:p=\"\(pNS)\">"
        xml += "<p:cSld><p:spTree>"
        xml += "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        xml += "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>"
        xml += "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        xml += "<p:sp>"
        xml += "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Notes Placeholder 1\"/>"
        xml += "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>"
        xml += "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr></p:nvSpPr>"
        xml += "<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
        xml += "</p:spTree></p:cSld>"
        xml += "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\""
        xml += " accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\""
        xml += " accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/>"
        xml += "</p:notesMaster>"
        return xml
    }

    /// `ppt/notesMasters/_rels/notesMaster1.xml.rels` — references the theme.
    public static func notesMasterRelsXML() -> String {
        let themeType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(relsNS)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(themeType)\" Target=\"../theme/theme1.xml\"/>"
        xml += "</Relationships>"
        return xml
    }
}

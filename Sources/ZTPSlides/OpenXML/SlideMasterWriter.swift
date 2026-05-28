// SlideMasterWriter.swift
// ZTPSlides – Generates slide master and layout XML for a PPTX package.

import Foundation

/// Produces the slide master and slide layout XML documents and their
/// relationship files. These are minimal implementations sufficient
/// for PowerPoint to open the file.
public struct SlideMasterWriter: Sendable {

    /// Generates `ppt/slideMasters/slideMaster1.xml`.
    ///
    /// - Returns: The complete XML string.
    public static func masterXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:sldMaster"
        xml += " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        xml += " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"

        xml += "<p:cSld>"
        xml += "<p:bg>"
        xml += "<p:bgRef idx=\"1001\">"
        xml += "<a:schemeClr val=\"bg1\"/>"
        xml += "</p:bgRef>"
        xml += "</p:bg>"
        xml += "<p:spTree>"
        xml += "<p:nvGrpSpPr>"
        xml += "<p:cNvPr id=\"1\" name=\"\"/>"
        xml += "<p:cNvGrpSpPr/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvGrpSpPr>"
        xml += "<p:grpSpPr/>"
        xml += "</p:spTree>"
        xml += "</p:cSld>"

        xml += "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\""
        xml += " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\""
        xml += " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\""
        xml += " hlink=\"hlink\" folHlink=\"folHlink\"/>"

        xml += "<p:sldLayoutIdLst>"
        xml += "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>"
        xml += "</p:sldLayoutIdLst>"

        xml += "</p:sldMaster>"
        return xml
    }

    /// Generates `ppt/slideLayouts/slideLayout1.xml`.
    ///
    /// - Returns: The complete XML string.
    public static func layoutXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:sldLayout"
        xml += " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        xml += " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""
        xml += " type=\"blank\" preserve=\"1\">"

        xml += "<p:cSld name=\"Blank\">"
        xml += "<p:spTree>"
        xml += "<p:nvGrpSpPr>"
        xml += "<p:cNvPr id=\"1\" name=\"\"/>"
        xml += "<p:cNvGrpSpPr/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvGrpSpPr>"
        xml += "<p:grpSpPr/>"
        xml += "</p:spTree>"
        xml += "</p:cSld>"

        xml += "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>"

        xml += "</p:sldLayout>"
        return xml
    }

    /// Generates `ppt/slideMasters/_rels/slideMaster1.xml.rels`.
    ///
    /// - Returns: The complete XML string.
    public static func masterRelsXML() -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let layoutType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
        let themeType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(layoutType)\" Target=\"../slideLayouts/slideLayout1.xml\"/>"
        xml += "<Relationship Id=\"rId2\" Type=\"\(themeType)\" Target=\"../theme/theme1.xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    /// Generates `ppt/slideLayouts/_rels/slideLayout1.xml.rels`.
    ///
    /// - Returns: The complete XML string.
    public static func layoutRelsXML() -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let masterType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(masterType)\" Target=\"../slideMasters/slideMaster1.xml\"/>"
        xml += "</Relationships>"
        return xml
    }
}

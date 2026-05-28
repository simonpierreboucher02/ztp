// ThemeWriter.swift
// ZTPSlides – Generates ppt/theme/theme1.xml for a PPTX package.

import Foundation

/// Produces the `ppt/theme/theme1.xml` document that defines
/// the visual theme (fonts, colors) for the presentation.
public struct ThemeWriter: Sendable {

    /// Generates the full `ppt/theme/theme1.xml` content.
    ///
    /// - Parameter theme: The theme configuration.
    /// - Returns: The complete XML string.
    public static func toXML(theme: PptxTheme) -> String {
        let esc = SlidesXMLEscaping.escape
        let fontName = esc(theme.font)
        let accent = theme.accent
        let bgColor = theme.background ?? "FFFFFF"
        let textColor = theme.textColor ?? "000000"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " name=\"\(esc(theme.name))\">"

        // Theme elements
        xml += "<a:themeElements>"

        // ---- Color scheme ----
        xml += "<a:clrScheme name=\"\(esc(theme.name))\">"
        xml += "<a:dk1><a:srgbClr val=\"\(textColor)\"/></a:dk1>"
        xml += "<a:lt1><a:srgbClr val=\"\(bgColor)\"/></a:lt1>"
        xml += "<a:dk2><a:srgbClr val=\"44546A\"/></a:dk2>"
        xml += "<a:lt2><a:srgbClr val=\"E7E6E6\"/></a:lt2>"
        xml += "<a:accent1><a:srgbClr val=\"\(accent)\"/></a:accent1>"
        xml += "<a:accent2><a:srgbClr val=\"ED7D31\"/></a:accent2>"
        xml += "<a:accent3><a:srgbClr val=\"A5A5A5\"/></a:accent3>"
        xml += "<a:accent4><a:srgbClr val=\"FFC000\"/></a:accent4>"
        xml += "<a:accent5><a:srgbClr val=\"5B9BD5\"/></a:accent5>"
        xml += "<a:accent6><a:srgbClr val=\"70AD47\"/></a:accent6>"
        xml += "<a:hlink><a:srgbClr val=\"0563C1\"/></a:hlink>"
        xml += "<a:folHlink><a:srgbClr val=\"954F72\"/></a:folHlink>"
        xml += "</a:clrScheme>"

        // ---- Font scheme ----
        xml += "<a:fontScheme name=\"\(esc(theme.name))\">"
        xml += "<a:majorFont>"
        xml += "<a:latin typeface=\"\(fontName)\"/>"
        xml += "<a:ea typeface=\"\"/>"
        xml += "<a:cs typeface=\"\"/>"
        xml += "</a:majorFont>"
        xml += "<a:minorFont>"
        xml += "<a:latin typeface=\"\(fontName)\"/>"
        xml += "<a:ea typeface=\"\"/>"
        xml += "<a:cs typeface=\"\"/>"
        xml += "</a:minorFont>"
        xml += "</a:fontScheme>"

        // ---- Format scheme ----
        xml += "<a:fmtScheme name=\"\(esc(theme.name))\">"

        // Fill styles
        xml += "<a:fillStyleLst>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "</a:fillStyleLst>"

        // Line styles
        xml += "<a:lnStyleLst>"
        xml += "<a:ln w=\"9525\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
        xml += "<a:ln w=\"25400\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
        xml += "<a:ln w=\"38100\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
        xml += "</a:lnStyleLst>"

        // Effect styles
        xml += "<a:effectStyleLst>"
        xml += "<a:effectStyle><a:effectLst/></a:effectStyle>"
        xml += "<a:effectStyle><a:effectLst/></a:effectStyle>"
        xml += "<a:effectStyle><a:effectLst/></a:effectStyle>"
        xml += "</a:effectStyleLst>"

        // Background fill styles
        xml += "<a:bgFillStyleLst>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        xml += "</a:bgFillStyleLst>"

        xml += "</a:fmtScheme>"

        xml += "</a:themeElements>"

        // Object defaults and extra color scheme list (required)
        xml += "<a:objectDefaults/>"
        xml += "<a:extraClrSchemeLst/>"

        xml += "</a:theme>"
        return xml
    }
}

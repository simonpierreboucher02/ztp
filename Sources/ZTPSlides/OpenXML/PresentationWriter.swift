// PresentationWriter.swift
// ZTPSlides – Generates ppt/presentation.xml for a PPTX package.

import Foundation

/// Produces the `ppt/presentation.xml` document that defines
/// the slide list, slide master references, and slide dimensions.
public struct PresentationWriter: Sendable {

    /// Generates the full `ppt/presentation.xml` content.
    ///
    /// - Parameters:
    ///   - slideCount: The number of slides in the presentation.
    ///   - size: The slide dimensions in EMU.
    /// - Returns: The complete XML string.
    public static func toXML(slideCount: Int, size: SlideSize) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:presentation"
        xml += " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        xml += " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"

        // Slide master reference
        xml += "<p:sldMasterIdLst>"
        xml += "<p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/>"
        xml += "</p:sldMasterIdLst>"

        // Slide list
        xml += "<p:sldIdLst>"
        for i in 0..<slideCount {
            let slideId = 256 + i
            let rId = "rId\(2 + i)"
            xml += "<p:sldId id=\"\(slideId)\" r:id=\"\(rId)\"/>"
        }
        xml += "</p:sldIdLst>"

        // Slide size
        xml += "<p:sldSz cx=\"\(size.width)\" cy=\"\(size.height)\"/>"

        // Notes size (standard letter portrait)
        xml += "<p:notesSz cx=\"6858000\" cy=\"9144000\"/>"

        xml += "</p:presentation>"
        return xml
    }
}

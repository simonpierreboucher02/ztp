// SlidesRelsWriter.swift
// ZTPSlides – Generates relationship XML files for a PPTX package.

import Foundation

/// Produces the relationship XML files that wire together the
/// various parts of a PPTX package.
public struct SlidesRelsWriter: Sendable {

    /// Generates the root `_rels/.rels` file.
    ///
    /// - Returns: The complete XML string.
    public static func rootRelsXML() -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let presType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        let coreType = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
        let appType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"
        xml += "<Relationship Id=\"rId1\" Type=\"\(presType)\" Target=\"ppt/presentation.xml\"/>"
        xml += "<Relationship Id=\"rId2\" Type=\"\(coreType)\" Target=\"docProps/core.xml\"/>"
        xml += "<Relationship Id=\"rId3\" Type=\"\(appType)\" Target=\"docProps/app.xml\"/>"
        xml += "</Relationships>"
        return xml
    }

    /// Generates `ppt/_rels/presentation.xml.rels`.
    ///
    /// Relationship order:
    /// - rId1 = slide master
    /// - rId2..rId(1+slideCount) = slides
    /// - rId(2+slideCount) = theme
    ///
    /// - Parameter slideCount: The number of slides.
    /// - Returns: The complete XML string.
    public static func presentationRelsXML(slideCount: Int, hasNotes: Bool = false) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let masterType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster"
        let slideType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"
        let themeType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"

        // Slide master
        xml += "<Relationship Id=\"rId1\" Type=\"\(masterType)\" Target=\"slideMasters/slideMaster1.xml\"/>"

        // Slides
        for i in 0..<slideCount {
            let rId = "rId\(2 + i)"
            xml += "<Relationship Id=\"\(rId)\" Type=\"\(slideType)\" Target=\"slides/slide\(i + 1).xml\"/>"
        }

        // Theme
        let themeRId = "rId\(2 + slideCount)"
        xml += "<Relationship Id=\"\(themeRId)\" Type=\"\(themeType)\" Target=\"theme/theme1.xml\"/>"

        if hasNotes {
            let notesMasterType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster"
            xml += "<Relationship Id=\"\(notesMasterRelId(slideCount: slideCount))\" Type=\"\(notesMasterType)\" Target=\"notesMasters/notesMaster1.xml\"/>"
        }

        xml += "</Relationships>"
        return xml
    }

    /// The relationship id used for the notes master in presentation.xml.rels.
    public static func notesMasterRelId(slideCount: Int) -> String {
        "rId\(3 + slideCount)"
    }

    /// Generates `ppt/slides/_rels/slideN.xml.rels`.
    ///
    /// rId1 always references the slide layout. Additional rIds reference images.
    ///
    /// - Parameter imageRelationships: Image relationships with rId and target path
    ///   (e.g. `("rId2", "../media/image1.png")`).
    /// - Returns: The complete XML string.
    public static func slideRelsXML(
        imageRelationships: [(rId: String, target: String)],
        notesSlideNumber: Int? = nil
    ) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/relationships"
        let layoutType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
        let imageType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
        let notesType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Relationships xmlns=\"\(ns)\">"

        // Slide layout reference
        xml += "<Relationship Id=\"rId1\" Type=\"\(layoutType)\" Target=\"../slideLayouts/slideLayout1.xml\"/>"

        // Image references
        for rel in imageRelationships {
            xml += "<Relationship Id=\"\(rel.rId)\" Type=\"\(imageType)\" Target=\"\(rel.target)\"/>"
        }

        // Speaker-notes reference
        if let n = notesSlideNumber {
            xml += "<Relationship Id=\"rIdNotes\" Type=\"\(notesType)\" Target=\"../notesSlides/notesSlide\(n).xml\"/>"
        }

        xml += "</Relationships>"
        return xml
    }
}

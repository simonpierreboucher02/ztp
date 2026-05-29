// SlidesContentTypes.swift
// ZTPSlides – Generates [Content_Types].xml for a PPTX package.

import Foundation

/// Produces the `[Content_Types].xml` document that lists every part
/// in the PPTX ZIP archive and its content type.
public struct SlidesContentTypes: Sendable {

    /// Generates the full `[Content_Types].xml` content.
    ///
    /// - Parameters:
    ///   - slideCount: The number of slides in the presentation.
    ///   - hasImages: Whether the presentation contains image elements.
    ///   - imageExtensions: The set of image file extensions used (e.g. "png", "jpg").
    /// - Returns: The complete XML string.
    public static func toXML(slideCount: Int, hasImages: Bool, imageExtensions: Set<String>, notesSlideNumbers: [Int] = []) -> String {
        let ns = "http://schemas.openxmlformats.org/package/2006/content-types"

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<Types xmlns=\"\(ns)\">"

        // Default extensions
        xml += "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        xml += "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"

        // Image extensions
        if hasImages {
            let mimeTypes: [String: String] = [
                "png": "image/png",
                "jpg": "image/jpeg",
                "jpeg": "image/jpeg",
                "gif": "image/gif",
                "bmp": "image/bmp",
                "tiff": "image/tiff",
                "tif": "image/tiff",
                "svg": "image/svg+xml",
                "emf": "image/x-emf",
                "wmf": "image/x-wmf"
            ]

            for ext in imageExtensions.sorted() {
                let mime = mimeTypes[ext] ?? "application/octet-stream"
                xml += "<Default Extension=\"\(ext)\" ContentType=\"\(mime)\"/>"
            }
        }

        // Presentation
        xml += "<Override PartName=\"/ppt/presentation.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>"

        // Slides
        for i in 1...max(slideCount, 1) {
            xml += "<Override PartName=\"/ppt/slides/slide\(i).xml\""
            xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
        }

        // Slide master
        xml += "<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/>"

        // Slide layout
        xml += "<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/>"

        // Theme
        xml += "<Override PartName=\"/ppt/theme/theme1.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>"

        // Notes master + notes slides
        if !notesSlideNumbers.isEmpty {
            xml += "<Override PartName=\"/ppt/notesMasters/notesMaster1.xml\""
            xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml\"/>"
            for n in notesSlideNumbers.sorted() {
                xml += "<Override PartName=\"/ppt/notesSlides/notesSlide\(n).xml\""
                xml += " ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>"
            }
        }

        // Core properties
        xml += "<Override PartName=\"/docProps/core.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"

        // App properties
        xml += "<Override PartName=\"/docProps/app.xml\""
        xml += " ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"

        xml += "</Types>"
        return xml
    }
}

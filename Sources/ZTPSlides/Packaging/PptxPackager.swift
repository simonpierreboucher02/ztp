// PptxPackager.swift
// ZTPSlides – Orchestrates the full PPTX ZIP archive generation

import Foundation

/// Orchestrates the generation of all OpenXML parts and packages them
/// into a valid `.pptx` ZIP archive.
public struct PptxPackager: Sendable {

    /// Errors specific to PPTX packaging.
    public enum PackagerError: Error, Sendable {
        /// An image file referenced by a slide could not be read.
        case imageNotFound(String)
        /// An XML part could not be encoded to UTF-8.
        case encodingError(String)
    }

    /// Generates a complete `.pptx` file as raw data.
    ///
    /// - Parameters:
    ///   - presentation: The presentation model to render.
    ///   - basePath: An optional base directory for resolving relative
    ///     image paths. If `nil`, image paths are treated as absolute.
    /// - Returns: The raw bytes of the ZIP archive.
    /// - Throws: ``PackagerError`` if an image cannot be found or an
    ///   encoding error occurs, or ``SlidesZIPWriter/ZIPError`` for ZIP
    ///   creation failures.
    public static func package(
        presentation: PptxPresentation,
        basePath: String? = nil
    ) throws -> Data {

        let slideCount = presentation.slides.count

        // ---- 1. Collect all images from all slides ----

        // Gather unique image paths in order across all slides
        var allImagePaths: [String] = []
        for slide in presentation.slides {
            for element in slide.content {
                if case let .image(img) = element {
                    if !allImagePaths.contains(img.path) {
                        allImagePaths.append(img.path)
                    }
                }
            }
        }

        let hasImages = !allImagePaths.isEmpty

        // Build global image data entries and extension set
        var globalImageData: [String: Data] = [:]          // path -> data
        var globalImageArchiveName: [String: String] = [:]  // path -> "imageN.ext"
        var imageExtensions: Set<String> = []

        for (index, path) in allImagePaths.enumerated() {
            let fullPath: String
            if path.hasPrefix("/") {
                fullPath = path
            } else if let base = basePath {
                fullPath = (base as NSString).appendingPathComponent(path)
            } else {
                fullPath = path
            }

            let fileURL = URL(fileURLWithPath: fullPath)
            let imageData: Data
            do {
                imageData = try Data(contentsOf: fileURL)
            } catch {
                throw PackagerError.imageNotFound(fullPath)
            }

            globalImageData[path] = imageData

            let ext = (path as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                imageExtensions.insert(ext)
            }
            let archiveName = "image\(index + 1).\(ext.isEmpty ? "png" : ext)"
            globalImageArchiveName[path] = archiveName
        }

        // ---- 2. Generate slide XMLs ----

        // For each slide, build the image relationships (imagePath -> rId)
        // and generate the slide XML and its rels XML.
        // In slide rels, rId1 is always the slideLayout; images start at rId2.

        var slideXMLs: [String] = []
        var slideRelsXMLs: [String] = []
        var slideImageEntries: [[SlidesZIPWriter.Entry]] = []

        for (slideIdx, slide) in presentation.slides.enumerated() {
            // Collect image paths used in this slide (in order, unique)
            var slideImagePaths: [String] = []
            for element in slide.content {
                if case let .image(img) = element {
                    if !slideImagePaths.contains(img.path) {
                        slideImagePaths.append(img.path)
                    }
                }
            }

            // Build per-slide image relationship map
            var imageRelationships: [String: String] = [:]   // path -> rId
            var imageRelsForSlide: [(rId: String, target: String)] = []
            var imgEntries: [SlidesZIPWriter.Entry] = []

            for (imgIdx, imgPath) in slideImagePaths.enumerated() {
                let rId = "rId\(2 + imgIdx)"  // rId1 = slideLayout
                imageRelationships[imgPath] = rId

                if let archiveName = globalImageArchiveName[imgPath] {
                    imageRelsForSlide.append((rId: rId, target: "../media/\(archiveName)"))

                    // Only add the media entry once globally (handled below)
                }
            }

            let slideXML = SlideWriter.toXML(
                slide: slide,
                slideIndex: slideIdx,
                theme: presentation.theme,
                size: presentation.size,
                imageRelationships: imageRelationships
            )
            slideXMLs.append(slideXML)

            let slideRelsXML = SlidesRelsWriter.slideRelsXML(
                imageRelationships: imageRelsForSlide
            )
            slideRelsXMLs.append(slideRelsXML)
            slideImageEntries.append(imgEntries)
        }

        // ---- 3. Generate all other XML parts ----

        let contentTypesXML = SlidesContentTypes.toXML(
            slideCount: slideCount,
            hasImages: hasImages,
            imageExtensions: imageExtensions
        )

        let rootRelsXML = SlidesRelsWriter.rootRelsXML()

        let presentationXML = PresentationWriter.toXML(
            slideCount: slideCount,
            size: presentation.size
        )

        let presentationRelsXML = SlidesRelsWriter.presentationRelsXML(
            slideCount: slideCount
        )

        let themeXML = ThemeWriter.toXML(theme: presentation.theme)

        let masterXML = SlideMasterWriter.masterXML()
        let layoutXML = SlideMasterWriter.layoutXML()
        let masterRelsXML = SlideMasterWriter.masterRelsXML()
        let layoutRelsXML = SlideMasterWriter.layoutRelsXML()

        let coreXML = SlidesDocProps.coreXML(
            title: presentation.title,
            author: presentation.author
        )
        let appXML = SlidesDocProps.appXML()

        // ---- 4. Build ZIP entries ----

        var entries: [SlidesZIPWriter.Entry] = []

        func addXMLEntry(_ path: String, _ xmlContent: String) throws {
            guard let data = xmlContent.data(using: .utf8) else {
                throw PackagerError.encodingError(path)
            }
            entries.append(SlidesZIPWriter.Entry(path: path, data: data))
        }

        try addXMLEntry("[Content_Types].xml", contentTypesXML)
        try addXMLEntry("_rels/.rels", rootRelsXML)
        try addXMLEntry("docProps/core.xml", coreXML)
        try addXMLEntry("docProps/app.xml", appXML)
        try addXMLEntry("ppt/presentation.xml", presentationXML)
        try addXMLEntry("ppt/_rels/presentation.xml.rels", presentationRelsXML)
        try addXMLEntry("ppt/theme/theme1.xml", themeXML)
        try addXMLEntry("ppt/slideMasters/slideMaster1.xml", masterXML)
        try addXMLEntry("ppt/slideMasters/_rels/slideMaster1.xml.rels", masterRelsXML)
        try addXMLEntry("ppt/slideLayouts/slideLayout1.xml", layoutXML)
        try addXMLEntry("ppt/slideLayouts/_rels/slideLayout1.xml.rels", layoutRelsXML)

        // Slide XMLs and their rels
        for i in 0..<slideCount {
            try addXMLEntry("ppt/slides/slide\(i + 1).xml", slideXMLs[i])
            try addXMLEntry("ppt/slides/_rels/slide\(i + 1).xml.rels", slideRelsXMLs[i])
        }

        // Image media files (each unique image once)
        for path in allImagePaths {
            if let data = globalImageData[path],
               let archiveName = globalImageArchiveName[path] {
                entries.append(SlidesZIPWriter.Entry(
                    path: "ppt/media/\(archiveName)",
                    data: data
                ))
            }
        }

        // ---- 5. Package into ZIP ----

        return try SlidesZIPWriter.createArchive(entries: entries)
    }
}

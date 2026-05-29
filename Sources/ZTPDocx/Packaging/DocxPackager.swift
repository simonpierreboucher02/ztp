// DocxPackager.swift
// ZTPDocx – Orchestrates the full DOCX ZIP archive generation

import Foundation

/// Orchestrates the generation of all OpenXML parts and packages them
/// into a valid `.docx` ZIP archive.
public struct DocxPackager: Sendable {

    /// Errors specific to DOCX packaging.
    public enum PackagerError: Error, Sendable {
        /// An image file referenced by the document could not be read.
        case imageNotFound(String)
        /// An XML part could not be encoded to UTF-8.
        case encodingError(String)
    }

    /// Generates a complete `.docx` file as raw data.
    ///
    /// - Parameters:
    ///   - document: The document model to render.
    ///   - styleRegistry: The style registry containing named styles.
    ///   - basePath: An optional base directory for resolving relative
    ///     image paths. If `nil`, image paths are treated as absolute.
    /// - Returns: The raw bytes of the ZIP archive.
    /// - Throws: ``PackagerError`` if an image cannot be found or an
    ///   encoding error occurs, or ``DocxZIPWriter/ZIPError`` for ZIP
    ///   creation failures.
    public static func package(
        document: DocxDocument,
        styleRegistry: DocxStyleRegistry,
        basePath: String? = nil
    ) throws -> Data {

        // 1. Collect all images and build relationships
        let allElements = document.sections.flatMap(\.elements)

        var imagePaths: [String] = []
        for element in allElements {
            if case let .image(docxImage) = element {
                if !imagePaths.contains(docxImage.path) {
                    imagePaths.append(docxImage.path)
                }
            }
        }

        // Build image relationship IDs and collect image data
        // rId1 = styles.xml, rId2 = numbering.xml, so images start at rId3
        var imageRelationships: [String: String] = [:]   // path -> rId
        var imageRelsForDoc: [(rId: String, target: String)] = []
        var imageEntries: [DocxZIPWriter.Entry] = []
        var imageExtensions: Set<String> = []
        let rIdOffset = 3  // images start at rId3

        for (index, path) in imagePaths.enumerated() {
            let rId = "rId\(index + rIdOffset)"
            imageRelationships[path] = rId

            // Resolve the full path
            let fullPath: String
            if path.hasPrefix("/") {
                fullPath = path
            } else if let base = basePath {
                fullPath = (base as NSString).appendingPathComponent(path)
            } else {
                fullPath = path
            }

            // Read the image data
            let fileURL = URL(fileURLWithPath: fullPath)
            let imageData: Data
            do {
                imageData = try Data(contentsOf: fileURL)
            } catch {
                throw PackagerError.imageNotFound(fullPath)
            }

            // Determine the file extension and archive target path
            let ext = (path as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                imageExtensions.insert(ext)
            }

            let archiveImageName = "image\(index + 1).\(ext.isEmpty ? "png" : ext)"
            let archiveTarget = "media/\(archiveImageName)"

            imageRelsForDoc.append((rId: rId, target: archiveTarget))
            imageEntries.append(DocxZIPWriter.Entry(
                path: "word/\(archiveTarget)",
                data: imageData
            ))
        }

        // 2. Determine if numbering is needed
        let hasNumbering = allElements.contains { element in
            switch element {
            case .bulletList, .numberedList:
                return true
            default:
                return false
            }
        }

        let hasImages = !imagePaths.isEmpty

        // 2b. Header / footer: the first section that defines them wins
        // (the document is rendered as a single section).
        let headerText = document.sections.compactMap(\.header).first(where: { !$0.isEmpty })
        let footerText = document.sections.compactMap(\.footer).first(where: { !$0.isEmpty })
        let hasHeader = headerText != nil
        let hasFooter = footerText != nil
        let headerRelId = hasHeader ? "rIdHeader1" : nil
        let footerRelId = hasFooter ? "rIdFooter1" : nil

        // 2c. Collect hyperlink targets from paragraph runs (unique, in order).
        var linkURLs: [String] = []
        for element in allElements {
            if case let .paragraph(runs, _, _) = element {
                for run in runs {
                    if let url = run.link, !url.isEmpty, !linkURLs.contains(url) {
                        linkURLs.append(url)
                    }
                }
            }
        }
        var hyperlinkRelationships: [String: String] = [:]   // url -> rId
        var hyperlinkRelsForDoc: [(rId: String, target: String)] = []
        for (i, url) in linkURLs.enumerated() {
            let rId = "rIdLink\(i + 1)"
            hyperlinkRelationships[url] = rId
            hyperlinkRelsForDoc.append((rId: rId, target: url))
        }

        // 3. Generate all XML content
        let contentTypesXML = DocxContentTypes.toXML(
            hasImages: hasImages,
            imageExtensions: imageExtensions,
            hasHeader: hasHeader,
            hasFooter: hasFooter
        )

        let rootRelsXML = DocxRelsWriter.rootRelsXML()

        let documentRelsXML = DocxRelsWriter.documentRelsXML(
            imageRelationships: imageRelsForDoc,
            hasNumbering: hasNumbering,
            headerRelId: headerRelId,
            footerRelId: footerRelId,
            hyperlinks: hyperlinkRelsForDoc
        )

        let documentXML = DocumentWriter.toXML(
            document: document,
            styleRegistry: styleRegistry,
            imageRelationships: imageRelationships,
            headerRelId: headerRelId,
            footerRelId: footerRelId,
            hyperlinkRelationships: hyperlinkRelationships
        )

        let stylesXML = DocxStylesWriter.toXML(registry: styleRegistry)

        let coreXML = DocxDocProps.coreXML(
            title: document.title,
            author: document.author
        )

        let appXML = DocxDocProps.appXML()

        // 4. Build ZIP entries
        var entries: [DocxZIPWriter.Entry] = []

        func addXMLEntry(_ path: String, _ xmlContent: String) throws {
            guard let data = xmlContent.data(using: .utf8) else {
                throw PackagerError.encodingError(path)
            }
            entries.append(DocxZIPWriter.Entry(path: path, data: data))
        }

        try addXMLEntry("[Content_Types].xml", contentTypesXML)
        try addXMLEntry("_rels/.rels", rootRelsXML)
        try addXMLEntry("docProps/core.xml", coreXML)
        try addXMLEntry("docProps/app.xml", appXML)
        try addXMLEntry("word/document.xml", documentXML)
        try addXMLEntry("word/styles.xml", stylesXML)
        try addXMLEntry("word/_rels/document.xml.rels", documentRelsXML)

        if hasNumbering {
            let numberingXML = NumberingWriter.toXML()
            try addXMLEntry("word/numbering.xml", numberingXML)
        }

        if let headerText {
            try addXMLEntry("word/header1.xml", HeaderFooterWriter.headerXML(text: headerText))
        }
        if let footerText {
            // A footer literal may include "{page}" to place a page number,
            // or page numbering is auto-appended when the footer mentions it.
            let wantsPage = footerText.lowercased().contains("page")
            try addXMLEntry("word/footer1.xml", HeaderFooterWriter.footerXML(text: footerText, pageNumbers: wantsPage))
        }

        // Add image file entries
        entries.append(contentsOf: imageEntries)

        // 5. Package into ZIP
        return try DocxZIPWriter.createArchive(entries: entries)
    }
}

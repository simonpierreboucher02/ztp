// SlidesInspector.swift
// ZTPSlides – Inspect .pptx files to extract metadata, structure, and content.

import Foundation

// MARK: - SlidesInspector

/// Provides read-only inspection of `.pptx` files without requiring a full
/// presentation model round-trip. Useful for agents that need to quickly
/// understand a presentation's structure.
public struct SlidesInspector: Sendable {

    // MARK: - Result Types

    /// High-level presentation information.
    public struct PresentationInfo: Codable, Sendable {
        public let title: String?
        public let author: String?
        public let slides: Int
        public let images: Int
        public let tables: Int
        public let theme: String?
    }

    /// A single slide's outline information.
    public struct SlideOutline: Codable, Sendable {
        public let index: Int
        public let title: String?
        public let textPreview: String?
    }

    /// A single slide's preview with element descriptions.
    public struct SlidePreview: Codable, Sendable {
        public let index: Int
        public let title: String?
        public let elements: [String]
    }

    // MARK: - Errors

    public enum InspectorError: Error, Sendable {
        case fileNotFound(String)
        case invalidPptx(String)
        case missingPresentationXML
    }

    // MARK: - Public API

    /// Inspects a `.pptx` file and returns high-level presentation information.
    ///
    /// - Parameter path: The file system path to the `.pptx` file.
    /// - Returns: A ``PresentationInfo`` with metadata and content counts.
    public static func inspect(at path: String) throws -> PresentationInfo {
        let entries = try readZipEntries(at: path)
        let entryMap = buildEntryMap(entries)

        // Extract slide count from presentation.xml
        guard let presentationXml = stringEntry(entryMap, path: "ppt/presentation.xml") else {
            throw InspectorError.missingPresentationXML
        }

        // Get slide references and resolve to actual slide paths
        let slidePaths = resolveSlideFiles(
            presentationXml: presentationXml,
            entryMap: entryMap
        )

        // Count images and tables across all slides
        var totalImages = 0
        var totalTables = 0

        for slidePath in slidePaths {
            if let slideXml = stringEntry(entryMap, path: slidePath) {
                totalImages += SlidesXMLParser.countImages(in: slideXml)
                totalTables += SlidesXMLParser.countTables(in: slideXml)
            }
        }

        // Extract title/author from core properties
        var title: String?
        var author: String?
        if let coreXml = stringEntry(entryMap, path: "docProps/core.xml") {
            title = SlidesXMLParser.extractTitle(from: coreXml)
            author = SlidesXMLParser.extractAuthor(from: coreXml)
        }

        // Extract theme name
        var themeName: String?
        if let themeXml = stringEntry(entryMap, path: "ppt/theme/theme1.xml") {
            themeName = SlidesXMLParser.extractThemeName(from: themeXml)
        }

        return PresentationInfo(
            title: title,
            author: author,
            slides: slidePaths.count,
            images: totalImages,
            tables: totalTables,
            theme: themeName
        )
    }

    /// Extracts the document outline (slide titles with indices).
    ///
    /// - Parameter path: The file system path to the `.pptx` file.
    /// - Returns: An array of ``SlideOutline`` in presentation order.
    public static func outline(at path: String) throws -> [SlideOutline] {
        let entries = try readZipEntries(at: path)
        let entryMap = buildEntryMap(entries)

        guard let presentationXml = stringEntry(entryMap, path: "ppt/presentation.xml") else {
            throw InspectorError.missingPresentationXML
        }

        let slidePaths = resolveSlideFiles(
            presentationXml: presentationXml,
            entryMap: entryMap
        )

        var outlines: [SlideOutline] = []

        for (index, slidePath) in slidePaths.enumerated() {
            var slideTitle: String?
            var textPreview: String?

            if let slideXml = stringEntry(entryMap, path: slidePath) {
                slideTitle = SlidesXMLParser.extractTitleFromSlide(slideXml)

                // Build text preview from all text runs
                let allTexts = SlidesXMLParser.extractTextFromSlide(slideXml)
                let preview = allTexts.joined(separator: " ")
                if !preview.isEmpty {
                    // Truncate to a reasonable preview length
                    textPreview = String(preview.prefix(200))
                }
            }

            outlines.append(SlideOutline(
                index: index + 1,
                title: slideTitle,
                textPreview: textPreview
            ))
        }

        return outlines
    }

    /// Extracts all text content from the presentation, joining slides with double newlines.
    ///
    /// - Parameter path: The file system path to the `.pptx` file.
    /// - Returns: The full text content of the presentation.
    public static func extractText(at path: String) throws -> String {
        let entries = try readZipEntries(at: path)
        let entryMap = buildEntryMap(entries)

        guard let presentationXml = stringEntry(entryMap, path: "ppt/presentation.xml") else {
            throw InspectorError.missingPresentationXML
        }

        let slidePaths = resolveSlideFiles(
            presentationXml: presentationXml,
            entryMap: entryMap
        )

        var slideTexts: [String] = []

        for slidePath in slidePaths {
            if let slideXml = stringEntry(entryMap, path: slidePath) {
                let texts = SlidesXMLParser.extractTextFromSlide(slideXml)
                if !texts.isEmpty {
                    slideTexts.append(texts.joined(separator: "\n"))
                }
            }
        }

        return slideTexts.joined(separator: "\n\n")
    }

    /// Generates a preview of each slide with title and element descriptions.
    ///
    /// - Parameter path: The file system path to the `.pptx` file.
    /// - Returns: An array of ``SlidePreview`` with element descriptions.
    public static func preview(at path: String) throws -> [SlidePreview] {
        let entries = try readZipEntries(at: path)
        let entryMap = buildEntryMap(entries)

        guard let presentationXml = stringEntry(entryMap, path: "ppt/presentation.xml") else {
            throw InspectorError.missingPresentationXML
        }

        let slidePaths = resolveSlideFiles(
            presentationXml: presentationXml,
            entryMap: entryMap
        )

        var previews: [SlidePreview] = []

        for (index, slidePath) in slidePaths.enumerated() {
            var slideTitle: String?
            var elements: [String] = []

            if let slideXml = stringEntry(entryMap, path: slidePath) {
                slideTitle = SlidesXMLParser.extractTitleFromSlide(slideXml)

                // Collect text elements
                let texts = SlidesXMLParser.extractTextFromSlide(slideXml)
                for text in texts {
                    elements.append("Text: \(text)")
                }

                // Count images
                let imageCount = SlidesXMLParser.countImages(in: slideXml)
                if imageCount > 0 {
                    elements.append("Images: \(imageCount)")
                }

                // Count tables
                let tableCount = SlidesXMLParser.countTables(in: slideXml)
                if tableCount > 0 {
                    elements.append("Tables: \(tableCount)")
                }
            }

            previews.append(SlidePreview(
                index: index + 1,
                title: slideTitle,
                elements: elements
            ))
        }

        return previews
    }

    // MARK: - Private Helpers

    /// Reads ZIP entries from a file at the given path.
    private static func readZipEntries(at path: String) throws -> [SlidesZIPReader.Entry] {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw InspectorError.fileNotFound(path)
        }
        return try SlidesZIPReader.readEntries(from: data)
    }

    /// Builds a dictionary mapping file paths to their data for quick lookup.
    private static func buildEntryMap(_ entries: [SlidesZIPReader.Entry]) -> [String: Data] {
        var map: [String: Data] = [:]
        for entry in entries {
            map[entry.path] = entry.data
        }
        return map
    }

    /// Retrieves a UTF-8 string from the entry map for a given path.
    private static func stringEntry(_ map: [String: Data], path: String) -> String? {
        guard let data = map[path] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Resolves slide file paths from presentation.xml by following relationships.
    ///
    /// Uses the slide references from presentation.xml and the relationship file
    /// to map rIds to actual slide paths (e.g., ppt/slides/slide1.xml).
    private static func resolveSlideFiles(
        presentationXml: String,
        entryMap: [String: Data]
    ) -> [String] {
        let slideRIds = SlidesXMLParser.extractSlideReferences(from: presentationXml)

        // Try to resolve via the rels file
        if let relsXml = stringEntry(entryMap, path: "ppt/_rels/presentation.xml.rels") {
            let relationships = SlidesXMLParser.extractRelationships(from: relsXml)
            let relMap = Dictionary(relationships.map { ($0.id, $0.target) }, uniquingKeysWith: { first, _ in first })

            var slidePaths: [String] = []
            for rId in slideRIds {
                if let target = relMap[rId] {
                    // Targets are relative to ppt/
                    let fullPath: String
                    if target.hasPrefix("/") {
                        fullPath = String(target.dropFirst())
                    } else {
                        fullPath = "ppt/" + target
                    }
                    slidePaths.append(fullPath)
                }
            }

            if !slidePaths.isEmpty {
                return slidePaths
            }
        }

        // Fallback: scan for slide files in the ZIP entries
        let slideFiles = entryMap.keys
            .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") && !$0.contains("_rels") }
            .sorted { path1, path2 in
                // Sort numerically by slide number
                let num1 = extractSlideNumber(from: path1) ?? 0
                let num2 = extractSlideNumber(from: path2) ?? 0
                return num1 < num2
            }

        return slideFiles
    }

    /// Extracts the numeric part from a slide path like "ppt/slides/slide3.xml" -> 3.
    private static func extractSlideNumber(from path: String) -> Int? {
        // Extract "slideN" part
        guard let slideRange = path.range(of: "slide") else { return nil }
        let afterSlide = path[slideRange.upperBound...]
        guard let dotRange = afterSlide.range(of: ".xml") else { return nil }
        let numberStr = String(afterSlide[afterSlide.startIndex..<dotRange.lowerBound])
        return Int(numberStr)
    }
}

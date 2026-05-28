// SlidesXMLParser.swift
// ZTPSlides – String-based XML extraction for PPTX files.

import Foundation

// MARK: - SlidesXMLParser

/// Lightweight string-based XML parser for extracting content from OOXML
/// presentation files. Uses string scanning rather than a full XML parser
/// to keep dependencies minimal.
struct SlidesXMLParser: Sendable {

    // MARK: - Slide References

    /// Extracts slide relationship IDs from `ppt/presentation.xml`.
    ///
    /// Looks for `<p:sldIdLst>` entries containing `r:id` attributes.
    static func extractSlideReferences(from presentationXml: String) -> [String] {
        var rIds: [String] = []

        // Find all <p:sldId ... r:id="rIdN" .../> elements
        let pattern = "<p:sldId "
        var searchStart = presentationXml.startIndex

        while let openRange = presentationXml.range(of: pattern, range: searchStart..<presentationXml.endIndex) {
            // Find the end of this tag (either "/>" or ">")
            guard let tagEnd = findTagEnd(in: presentationXml, from: openRange.upperBound) else {
                break
            }

            let tagContent = String(presentationXml[openRange.lowerBound..<tagEnd])

            if let rId = extractSimpleAttribute(from: tagContent, name: "r:id") {
                rIds.append(rId)
            }

            searchStart = tagEnd
        }

        return rIds
    }

    // MARK: - Relationships

    /// Extracts relationships from a `.rels` XML file.
    static func extractRelationships(from relsXml: String) -> [(id: String, target: String, type: String)] {
        var results: [(id: String, target: String, type: String)] = []

        let pattern = "<Relationship "
        var searchStart = relsXml.startIndex

        while let openRange = relsXml.range(of: pattern, range: searchStart..<relsXml.endIndex) {
            guard let tagEnd = findTagEnd(in: relsXml, from: openRange.upperBound) else {
                break
            }

            let tagContent = String(relsXml[openRange.lowerBound..<tagEnd])

            let id = extractSimpleAttribute(from: tagContent, name: "Id") ?? ""
            let target = extractSimpleAttribute(from: tagContent, name: "Target") ?? ""
            let type = extractSimpleAttribute(from: tagContent, name: "Type") ?? ""
            results.append((id: id, target: target, type: type))

            searchStart = tagEnd
        }

        return results
    }

    // MARK: - Text Extraction

    /// Extracts all text runs from a slide XML.
    ///
    /// Finds all `<a:t>` elements and returns their text content.
    static func extractTextFromSlide(_ xml: String) -> [String] {
        var texts: [String] = []

        // Match both <a:t>...</a:t> and <a:t ...>...</a:t>
        let patterns = ["<a:t>", "<a:t "]
        for pattern in patterns {
            var searchStart = xml.startIndex
            while let openRange = xml.range(of: pattern, range: searchStart..<xml.endIndex) {
                // Find end of opening tag
                guard let tagEnd = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) else {
                    break
                }
                let contentStart = pattern == "<a:t>" ? openRange.upperBound : tagEnd.upperBound

                // Find </a:t>
                guard let closeRange = xml.range(of: "</a:t>", range: contentStart..<xml.endIndex) else {
                    break
                }

                let text = String(xml[contentStart..<closeRange.lowerBound])
                if !text.isEmpty {
                    texts.append(decodeXMLEntities(text))
                }
                searchStart = closeRange.upperBound
            }
        }

        return texts
    }

    // MARK: - Title Extraction

    /// Extracts the title from a slide XML.
    ///
    /// Looks for the first `<p:sp>` shape that contains text, which is
    /// typically the title placeholder. Also checks for title placeholder
    /// type attributes.
    static func extractTitleFromSlide(_ xml: String) -> String? {
        // Strategy 1: Look for a shape with a title placeholder type
        // <p:ph type="title"/> or <p:ph type="ctrTitle"/>
        let titleTypes = ["type=\"title\"", "type=\"ctrTitle\""]
        for titleType in titleTypes {
            if let title = extractTextFromPlaceholder(xml: xml, placeholderPattern: titleType) {
                return title
            }
        }

        // Strategy 2: Fall back to the first <p:sp> with text content
        let spBlocks = extractBlocks(from: xml, openTag: "<p:sp>", closeTag: "</p:sp>") +
                       extractBlocks(from: xml, openTag: "<p:sp ", closeTag: "</p:sp>")

        for block in spBlocks {
            let texts = extractTextFromSlide(block)
            if let firstText = texts.first, !firstText.isEmpty {
                return firstText
            }
        }

        return nil
    }

    // MARK: - Content Counting

    /// Counts the number of images (`<p:pic>`) in a slide XML.
    static func countImages(in xml: String) -> Int {
        var count = 0
        var searchStart = xml.startIndex

        // Count <p:pic> and <p:pic ... elements
        let patterns = ["<p:pic>", "<p:pic "]
        for pattern in patterns {
            searchStart = xml.startIndex
            while let range = xml.range(of: pattern, range: searchStart..<xml.endIndex) {
                count += 1
                searchStart = range.upperBound
            }
        }

        return count
    }

    /// Counts the number of tables (`<a:tbl>`) in a slide XML.
    static func countTables(in xml: String) -> Int {
        var count = 0
        var searchStart = xml.startIndex

        let patterns = ["<a:tbl>", "<a:tbl "]
        for pattern in patterns {
            searchStart = xml.startIndex
            while let range = xml.range(of: pattern, range: searchStart..<xml.endIndex) {
                count += 1
                searchStart = range.upperBound
            }
        }

        return count
    }

    // MARK: - Core Properties

    /// Extracts the document title from `docProps/core.xml`.
    static func extractTitle(from coreXml: String) -> String? {
        if let value = extractTagContent(from: coreXml, tag: "dc:title") {
            return decodeXMLEntities(value)
        }
        return nil
    }

    /// Extracts the document author from `docProps/core.xml`.
    static func extractAuthor(from coreXml: String) -> String? {
        if let value = extractTagContent(from: coreXml, tag: "dc:creator") {
            return decodeXMLEntities(value)
        }
        return nil
    }

    // MARK: - Theme

    /// Extracts the theme name from a theme XML file.
    ///
    /// Looks for the `name` attribute on `<a:theme>`.
    static func extractThemeName(from themeXml: String) -> String? {
        // <a:theme ... name="...">
        let pattern = "<a:theme "
        guard let openRange = themeXml.range(of: pattern) else {
            return nil
        }

        guard let tagEnd = findTagEnd(in: themeXml, from: openRange.upperBound) else {
            return nil
        }

        let tagContent = String(themeXml[openRange.lowerBound..<tagEnd])
        return extractSimpleAttribute(from: tagContent, name: "name")
    }

    // MARK: - Private Helpers

    /// Extracts text from a shape that contains a placeholder matching the given pattern.
    private static func extractTextFromPlaceholder(xml: String, placeholderPattern: String) -> String? {
        let spBlocks = extractBlocks(from: xml, openTag: "<p:sp>", closeTag: "</p:sp>") +
                       extractBlocks(from: xml, openTag: "<p:sp ", closeTag: "</p:sp>")

        for block in spBlocks {
            if block.contains(placeholderPattern) {
                let texts = extractTextFromSlide(block)
                let joined = texts.joined()
                if !joined.isEmpty {
                    return joined
                }
            }
        }

        return nil
    }

    /// Extracts all blocks between a given open and close tag pair.
    ///
    /// Handles nested tags by tracking depth.
    private static func extractBlocks(from xml: String, openTag: String, closeTag: String) -> [String] {
        var blocks: [String] = []
        var searchStart = xml.startIndex

        while let openRange = xml.range(of: openTag, range: searchStart..<xml.endIndex) {
            // Find the end of the opening tag (the first '>' after the match)
            guard let openTagEnd = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) else {
                break
            }

            let contentStart = openTagEnd.upperBound

            // Find the matching close tag, handling nesting
            var depth = 1
            var scanPos = contentStart
            var matchEnd: String.Index?

            let tagPrefix = openTag.hasSuffix(" ") ? String(openTag.dropLast()) : openTag

            while depth > 0 {
                let nextClose = xml.range(of: closeTag, range: scanPos..<xml.endIndex)
                let nextOpen1 = xml.range(of: tagPrefix + " ", range: scanPos..<xml.endIndex)
                let nextOpen2 = xml.range(of: tagPrefix + ">", range: scanPos..<xml.endIndex)

                var nextOpen: Range<String.Index>?
                if let o1 = nextOpen1, let o2 = nextOpen2 {
                    nextOpen = o1.lowerBound < o2.lowerBound ? o1 : o2
                } else {
                    nextOpen = nextOpen1 ?? nextOpen2
                }

                guard let closeRange = nextClose else {
                    break
                }

                if let openRange2 = nextOpen, openRange2.lowerBound < closeRange.lowerBound {
                    depth += 1
                    scanPos = openRange2.upperBound
                } else {
                    depth -= 1
                    if depth == 0 {
                        matchEnd = closeRange.lowerBound
                    }
                    scanPos = closeRange.upperBound
                }
            }

            if let end = matchEnd {
                let block = String(xml[contentStart..<end])
                blocks.append(block)
                searchStart = xml.index(end, offsetBy: closeTag.count, limitedBy: xml.endIndex) ?? xml.endIndex
            } else {
                break
            }
        }

        return blocks
    }

    /// Finds the end of a tag starting from a position (finds the next ">" or "/>").
    private static func findTagEnd(in xml: String, from start: String.Index) -> String.Index? {
        if let closeSlash = xml.range(of: "/>", range: start..<xml.endIndex),
           let closeAngle = xml.range(of: ">", range: start..<xml.endIndex) {
            // Return whichever comes first
            return closeSlash.lowerBound < closeAngle.lowerBound
                ? closeSlash.upperBound
                : closeAngle.upperBound
        }
        if let closeAngle = xml.range(of: ">", range: start..<xml.endIndex) {
            return closeAngle.upperBound
        }
        return nil
    }

    /// Extracts the text content of a simple tag like `<dc:title>text</dc:title>`.
    private static func extractTagContent(from xml: String, tag: String) -> String? {
        let openPattern = "<" + tag + ">"
        let openPatternAttr = "<" + tag + " "
        let closePattern = "</" + tag + ">"

        // Try exact tag first
        if let openRange = xml.range(of: openPattern) {
            let contentStart = openRange.upperBound
            if let closeRange = xml.range(of: closePattern, range: contentStart..<xml.endIndex) {
                let content = String(xml[contentStart..<closeRange.lowerBound])
                return content.isEmpty ? nil : content
            }
        }

        // Try tag with attributes
        if let openRange = xml.range(of: openPatternAttr) {
            if let tagEnd = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) {
                let contentStart = tagEnd.upperBound
                if let closeRange = xml.range(of: closePattern, range: contentStart..<xml.endIndex) {
                    let content = String(xml[contentStart..<closeRange.lowerBound])
                    return content.isEmpty ? nil : content
                }
            }
        }

        return nil
    }

    /// Extracts a simple attribute value from a tag string.
    private static func extractSimpleAttribute(from tagString: String, name: String) -> String? {
        let pattern = name + "=\""
        guard let attrRange = tagString.range(of: pattern) else {
            return nil
        }

        let valueStart = attrRange.upperBound
        guard let quoteEnd = tagString.range(of: "\"", range: valueStart..<tagString.endIndex) else {
            return nil
        }

        return String(tagString[valueStart..<quoteEnd.lowerBound])
    }

    /// Decodes standard XML entities in a string.
    static func decodeXMLEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        return result
    }
}

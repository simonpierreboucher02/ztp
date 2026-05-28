// DocxXMLParser.swift
// ZTPDocx – String-based XML extraction for DOCX files.

import Foundation

// MARK: - DocxXMLParser

/// Lightweight string-based XML parser for extracting content from OOXML
/// `word/document.xml` and related files. Uses string scanning rather than
/// a full XML parser to keep dependencies minimal.
struct DocxXMLParser: Sendable {

    // MARK: - Paragraphs

    /// Extracts all paragraphs from a `word/document.xml` string.
    ///
    /// Each paragraph returns its concatenated run text and optional style
    /// (from `<w:pStyle w:val="..."/>`).
    static func extractParagraphs(from xml: String) -> [(text: String, style: String?)] {
        var results: [(text: String, style: String?)] = []

        for block in extractBlocks(from: xml, openTag: "<w:p ", closeTag: "</w:p>") +
                      extractBlocks(from: xml, openTag: "<w:p>", closeTag: "</w:p>") {
            let text = extractRunText(from: block)
            let style = extractAttributeValue(from: block, tag: "w:pStyle", attribute: "w:val")
            results.append((text: decodeXMLEntities(text), style: style))
        }

        return results
    }

    // MARK: - Headings

    /// Extracts headings from `word/document.xml`.
    ///
    /// Headings are paragraphs whose style matches `Heading1`...`Heading9`
    /// (or the pattern `HeadingN`).
    static func extractHeadings(from xml: String) -> [(level: Int, text: String)] {
        let paragraphs = extractParagraphs(from: xml)
        var headings: [(level: Int, text: String)] = []

        for para in paragraphs {
            guard let style = para.style else { continue }
            if let level = headingLevel(from: style) {
                headings.append((level: level, text: para.text))
            }
        }

        return headings
    }

    // MARK: - Tables

    /// Extracts all tables from `word/document.xml`.
    ///
    /// Returns an array of tables; each table is an array of rows; each row
    /// is an array of cell text strings.
    static func extractTables(from xml: String) -> [[[String]]] {
        var tables: [[[String]]] = []

        for tableBlock in extractBlocks(from: xml, openTag: "<w:tbl>", closeTag: "</w:tbl>") +
                          extractBlocks(from: xml, openTag: "<w:tbl ", closeTag: "</w:tbl>") {
            var rows: [[String]] = []

            for rowBlock in extractBlocks(from: tableBlock, openTag: "<w:tr>", closeTag: "</w:tr>") +
                            extractBlocks(from: tableBlock, openTag: "<w:tr ", closeTag: "</w:tr>") {
                var cells: [String] = []

                for cellBlock in extractBlocks(from: rowBlock, openTag: "<w:tc>", closeTag: "</w:tc>") +
                                 extractBlocks(from: rowBlock, openTag: "<w:tc ", closeTag: "</w:tc>") {
                    let cellText = extractRunText(from: cellBlock)
                    cells.append(decodeXMLEntities(cellText))
                }

                rows.append(cells)
            }

            tables.append(rows)
        }

        return tables
    }

    // MARK: - Images

    /// Extracts image relationship IDs from `word/document.xml`.
    ///
    /// Looks for `<a:blip r:embed="rIdN"/>` patterns.
    static func extractImages(from xml: String) -> [String] {
        var ids: [String] = []
        let pattern = "r:embed=\""

        var searchStart = xml.startIndex
        while let range = xml.range(of: pattern, range: searchStart..<xml.endIndex) {
            let valueStart = range.upperBound
            if let quoteEnd = xml.range(of: "\"", range: valueStart..<xml.endIndex) {
                let rid = String(xml[valueStart..<quoteEnd.lowerBound])
                if !rid.isEmpty {
                    ids.append(rid)
                }
                searchStart = quoteEnd.upperBound
            } else {
                break
            }
        }

        return ids
    }

    // MARK: - Relationships

    /// Extracts relationships from a `.rels` XML file.
    static func extractRelationships(from xml: String) -> [(id: String, target: String, type: String)] {
        var results: [(id: String, target: String, type: String)] = []

        // Find all <Relationship .../> elements
        for block in extractSelfClosingTags(from: xml, tagName: "Relationship") {
            let id = extractSimpleAttribute(from: block, name: "Id") ?? ""
            let target = extractSimpleAttribute(from: block, name: "Target") ?? ""
            let type = extractSimpleAttribute(from: block, name: "Type") ?? ""
            results.append((id: id, target: target, type: type))
        }

        return results
    }

    // MARK: - Core Properties

    /// Extracts the document title from `docProps/core.xml`.
    static func extractTitle(from coreXml: String) -> String? {
        // Try <dc:title>...</dc:title>
        if let value = extractTagContent(from: coreXml, tag: "dc:title") {
            return decodeXMLEntities(value)
        }
        return nil
    }

    /// Extracts the document author from `docProps/core.xml`.
    static func extractAuthor(from coreXml: String) -> String? {
        // Try <dc:creator>...</dc:creator>
        if let value = extractTagContent(from: coreXml, tag: "dc:creator") {
            return decodeXMLEntities(value)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Extracts all blocks between a given open and close tag pair.
    ///
    /// This handles nested tags by tracking depth. The returned blocks
    /// include the content between the open and close tags (excluding the
    /// tags themselves for the outermost pair).
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

            // Determine the simple tag name for nesting detection
            // e.g. "<w:p " -> "<w:p" for detecting nested opens
            let tagPrefix = openTag.hasSuffix(" ") ? String(openTag.dropLast()) : openTag

            while depth > 0 {
                // Find the next occurrence of either the open or close tag
                let nextClose = xml.range(of: closeTag, range: scanPos..<xml.endIndex)
                let nextOpen1 = xml.range(of: tagPrefix + " ", range: scanPos..<xml.endIndex)
                let nextOpen2 = xml.range(of: tagPrefix + ">", range: scanPos..<xml.endIndex)

                // Determine which nested open comes first
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

    /// Extracts all text from `<w:t>` (and `<w:t `) elements within a block.
    private static func extractRunText(from block: String) -> String {
        var text = ""

        // Match both <w:t>...</w:t> and <w:t xml:space="preserve">...</w:t>
        let patterns = ["<w:t>", "<w:t "]
        for pattern in patterns {
            var searchStart = block.startIndex
            while let openRange = block.range(of: pattern, range: searchStart..<block.endIndex) {
                // Find end of opening tag
                guard let tagEnd = block.range(of: ">", range: openRange.upperBound..<block.endIndex) else {
                    break
                }
                let contentStart = tagEnd.upperBound

                // Find </w:t>
                guard let closeRange = block.range(of: "</w:t>", range: contentStart..<block.endIndex) else {
                    break
                }

                text += String(block[contentStart..<closeRange.lowerBound])
                searchStart = closeRange.upperBound
            }
        }

        return text
    }

    /// Extracts the value of an attribute from a tag within a block.
    ///
    /// For example, to find `w:val` from `<w:pStyle w:val="Heading1"/>`,
    /// call `extractAttributeValue(from: block, tag: "w:pStyle", attribute: "w:val")`.
    private static func extractAttributeValue(from block: String, tag: String, attribute: String) -> String? {
        let tagPattern = "<" + tag + " "

        guard let tagRange = block.range(of: tagPattern) else {
            return nil
        }

        // Find the end of this tag element (either "/>" or ">")
        guard let tagEnd = block.range(of: ">", range: tagRange.upperBound..<block.endIndex) else {
            return nil
        }

        let tagContent = String(block[tagRange.upperBound..<tagEnd.lowerBound])
        let attrPattern = attribute + "=\""

        guard let attrRange = tagContent.range(of: attrPattern) else {
            return nil
        }

        let valueStart = attrRange.upperBound
        guard let quoteEnd = tagContent.range(of: "\"", range: valueStart..<tagContent.endIndex) else {
            return nil
        }

        return String(tagContent[valueStart..<quoteEnd.lowerBound])
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

    /// Extracts self-closing tag occurrences like `<Relationship Id="..." Target="..." Type="..."/>`.
    private static func extractSelfClosingTags(from xml: String, tagName: String) -> [String] {
        var results: [String] = []
        let pattern = "<" + tagName + " "

        var searchStart = xml.startIndex
        while let openRange = xml.range(of: pattern, range: searchStart..<xml.endIndex) {
            // Find the closing "/>" or ">"
            if let closeRange = xml.range(of: "/>", range: openRange.upperBound..<xml.endIndex) {
                // Check there is no ">" before "/>"
                let fullTag = String(xml[openRange.lowerBound..<closeRange.upperBound])
                results.append(fullTag)
                searchStart = closeRange.upperBound
            } else if let closeRange = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) {
                let fullTag = String(xml[openRange.lowerBound..<closeRange.upperBound])
                results.append(fullTag)
                searchStart = closeRange.upperBound
            } else {
                break
            }
        }

        return results
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

    /// Determines heading level from a paragraph style name.
    ///
    /// Recognizes patterns like "Heading1", "heading2", "Titre1" (French), etc.
    private static func headingLevel(from style: String) -> Int? {
        let lowered = style.lowercased()

        // Match "heading1" through "heading9"
        if lowered.hasPrefix("heading") {
            let suffix = String(lowered.dropFirst(7))
            if let level = Int(suffix), level >= 1 && level <= 9 {
                return level
            }
        }

        // Match "titre1" through "titre9" (French localization)
        if lowered.hasPrefix("titre") {
            let suffix = String(lowered.dropFirst(5))
            if let level = Int(suffix), level >= 1 && level <= 9 {
                return level
            }
        }

        return nil
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

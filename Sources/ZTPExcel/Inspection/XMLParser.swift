// XMLParser.swift
// ZTPExcel – Lightweight XML data extraction helpers for OpenXML.

import Foundation

/// A minimal XML data extractor for reading OpenXML worksheet and workbook
/// structures without a full-featured XML parser.
///
/// Uses simple string scanning to pull data from well-known OpenXML elements.
struct SimpleXMLExtractor: Sendable {

    // MARK: - Sheet names from xl/workbook.xml

    /// Extracts sheet names from `xl/workbook.xml`.
    ///
    /// Looks for `<sheet name="..." ... />` elements.
    static func extractSheetNames(from xml: String) -> [String] {
        var names: [String] = []
        var searchStart = xml.startIndex

        while let sheetRange = xml.range(of: "<sheet ", range: searchStart..<xml.endIndex) {
            // Find the end of this element
            guard let closeRange = xml.range(of: ">", range: sheetRange.upperBound..<xml.endIndex) else {
                break
            }
            let element = String(xml[sheetRange.lowerBound..<closeRange.upperBound])

            if let name = extractAttribute(named: "name", from: element) {
                names.append(name)
            }

            searchStart = closeRange.upperBound
        }

        return names
    }

    // MARK: - Cell data from worksheet XML

    /// Extracts cell data from a worksheet XML string.
    ///
    /// Looks for `<c r="..." t="..." s="...">` elements containing `<v>` and `<f>` children.
    static func extractCells(from xml: String) -> [(ref: String, type: String?, value: String?, formula: String?)] {
        var cells: [(ref: String, type: String?, value: String?, formula: String?)] = []
        var searchStart = xml.startIndex

        while let cRange = findNextCellElement(in: xml, from: searchStart) {
            let element = String(xml[cRange.lowerBound..<cRange.upperBound])
            searchStart = cRange.upperBound

            guard let ref = extractAttribute(named: "r", from: element) else {
                continue
            }

            let type = extractAttribute(named: "t", from: element)
            let styleStr = extractAttribute(named: "s", from: element)
            let _ = styleStr // available if needed

            let value = extractChildContent(tag: "v", from: element)
            let formula = extractChildContent(tag: "f", from: element)

            cells.append((ref: ref, type: type, value: value, formula: formula))
        }

        return cells
    }

    // MARK: - Shared strings from xl/sharedStrings.xml

    /// Extracts shared strings from `xl/sharedStrings.xml`.
    ///
    /// Looks for `<si>` elements containing `<t>` tags.
    static func extractSharedStrings(from xml: String) -> [String] {
        var strings: [String] = []
        var searchStart = xml.startIndex

        while let siRange = xml.range(of: "<si>", range: searchStart..<xml.endIndex) {
            guard let siClose = xml.range(of: "</si>", range: siRange.upperBound..<xml.endIndex) else {
                break
            }

            let siContent = String(xml[siRange.upperBound..<siClose.lowerBound])

            // The string might be in a single <t> or multiple <r><t> (rich text) runs.
            let textParts = extractAllChildContents(tag: "t", from: siContent)
            let combined = textParts.joined()
            strings.append(combined)

            searchStart = siClose.upperBound
        }

        return strings
    }

    // MARK: - Style detection

    /// Checks whether the XML contains any `<xf>` elements (cell style format entries).
    static func hasStyles(in xml: String) -> Bool {
        xml.range(of: "<xf ") != nil || xml.range(of: "<xf>") != nil
    }

    // MARK: - Sheet relationship IDs

    /// Extracts the `sheetId` and `r:id` for each sheet from workbook.xml.
    static func extractSheetRelations(from xml: String) -> [(name: String, sheetId: String, rId: String)] {
        var relations: [(name: String, sheetId: String, rId: String)] = []
        var searchStart = xml.startIndex

        while let sheetRange = xml.range(of: "<sheet ", range: searchStart..<xml.endIndex) {
            guard let closeRange = xml.range(of: ">", range: sheetRange.upperBound..<xml.endIndex) else {
                break
            }
            let element = String(xml[sheetRange.lowerBound..<closeRange.upperBound])

            if let name = extractAttribute(named: "name", from: element),
               let sheetId = extractAttribute(named: "sheetId", from: element),
               let rId = extractAttribute(named: "r:id", from: element) {
                relations.append((name: name, sheetId: sheetId, rId: rId))
            }

            searchStart = closeRange.upperBound
        }

        return relations
    }

    /// Extracts relationship targets from a .rels XML file.
    ///
    /// Returns tuples of (Id, Target) from `<Relationship Id="..." Target="..."/>` elements.
    static func extractRelationships(from xml: String) -> [(id: String, target: String)] {
        var rels: [(id: String, target: String)] = []
        var searchStart = xml.startIndex

        while let relRange = xml.range(of: "<Relationship ", range: searchStart..<xml.endIndex) {
            guard let closeRange = xml.range(of: ">", range: relRange.upperBound..<xml.endIndex) else {
                break
            }
            let element = String(xml[relRange.lowerBound..<closeRange.upperBound])

            if let id = extractAttribute(named: "Id", from: element),
               let target = extractAttribute(named: "Target", from: element) {
                rels.append((id: id, target: target))
            }

            searchStart = closeRange.upperBound
        }

        return rels
    }

    // MARK: - Private helpers

    /// Finds the next `<c ...>...</c>` or self-closing `<c .../>` element.
    private static func findNextCellElement(in xml: String, from start: String.Index) -> Range<String.Index>? {
        // Look for <c followed by space or >
        var searchPos = start
        while searchPos < xml.endIndex {
            guard let openRange = xml.range(of: "<c", range: searchPos..<xml.endIndex) else {
                return nil
            }

            // Ensure it's actually <c with a space, > or / following (not <col, <cols, etc.)
            let afterC = openRange.upperBound
            guard afterC < xml.endIndex else { return nil }
            let nextChar = xml[afterC]

            if nextChar == " " || nextChar == ">" || nextChar == "/" {
                // Found a <c element. Now find its end.
                // Check for self-closing
                if let selfClose = xml.range(of: "/>", range: afterC..<xml.endIndex),
                   let endTag = xml.range(of: "</c>", range: afterC..<xml.endIndex) {
                    // Use whichever comes first
                    if selfClose.lowerBound < endTag.lowerBound {
                        return openRange.lowerBound..<selfClose.upperBound
                    } else {
                        return openRange.lowerBound..<endTag.upperBound
                    }
                } else if let selfClose = xml.range(of: "/>", range: afterC..<xml.endIndex) {
                    return openRange.lowerBound..<selfClose.upperBound
                } else if let endTag = xml.range(of: "</c>", range: afterC..<xml.endIndex) {
                    return openRange.lowerBound..<endTag.upperBound
                } else {
                    return nil
                }
            }

            // Not a <c element — keep searching
            searchPos = openRange.upperBound
        }

        return nil
    }

    /// Extracts the value of an XML attribute by name from an element string.
    private static func extractAttribute(named name: String, from element: String) -> String? {
        // Look for name="..." or name='...'
        let patterns = ["\(name)=\"", "\(name)='"]

        for pattern in patterns {
            guard let startRange = element.range(of: pattern) else { continue }
            let quote: Character = pattern.last!
            let valueStart = startRange.upperBound
            guard let endRange = element.range(of: String(quote), range: valueStart..<element.endIndex) else {
                continue
            }
            let value = String(element[valueStart..<endRange.lowerBound])
            return decodeXMLEntities(value)
        }

        return nil
    }

    /// Extracts the text content of the first child element with the given tag name.
    private static func extractChildContent(tag: String, from element: String) -> String? {
        let openTag = "<\(tag)>"
        let openTagAlt = "<\(tag) "
        let closeTag = "</\(tag)>"

        // Try simple <tag>content</tag>
        if let openRange = element.range(of: openTag) {
            if let closeRange = element.range(of: closeTag, range: openRange.upperBound..<element.endIndex) {
                return decodeXMLEntities(String(element[openRange.upperBound..<closeRange.lowerBound]))
            }
        }

        // Try <tag attr="...">content</tag>
        if let openRange = element.range(of: openTagAlt) {
            if let gtRange = element.range(of: ">", range: openRange.upperBound..<element.endIndex) {
                if let closeRange = element.range(of: closeTag, range: gtRange.upperBound..<element.endIndex) {
                    return decodeXMLEntities(String(element[gtRange.upperBound..<closeRange.lowerBound]))
                }
            }
        }

        return nil
    }

    /// Extracts all occurrences of `<tag>content</tag>` within a string.
    private static func extractAllChildContents(tag: String, from text: String) -> [String] {
        var results: [String] = []
        var searchStart = text.startIndex
        let openTag = "<\(tag)>"
        let openTagAlt = "<\(tag) "
        let closeTag = "</\(tag)>"

        while searchStart < text.endIndex {
            var contentStart: String.Index?

            // Try <tag>
            if let openRange = text.range(of: openTag, range: searchStart..<text.endIndex) {
                contentStart = openRange.upperBound
            } else if let openRange = text.range(of: openTagAlt, range: searchStart..<text.endIndex) {
                // <tag attr="...">
                if let gtRange = text.range(of: ">", range: openRange.upperBound..<text.endIndex) {
                    contentStart = gtRange.upperBound
                }
            }

            guard let start = contentStart else { break }

            if let closeRange = text.range(of: closeTag, range: start..<text.endIndex) {
                results.append(decodeXMLEntities(String(text[start..<closeRange.lowerBound])))
                searchStart = closeRange.upperBound
            } else {
                break
            }
        }

        return results
    }

    /// Decodes basic XML entities.
    private static func decodeXMLEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        return result
    }
}

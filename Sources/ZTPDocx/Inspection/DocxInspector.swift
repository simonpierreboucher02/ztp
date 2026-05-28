// DocxInspector.swift
// ZTPDocx – Inspect .docx files to extract metadata, structure, and content.

import Foundation

// MARK: - DocxInspector

/// Provides read-only inspection of `.docx` files without requiring a full
/// document model round-trip. Useful for agents that need to quickly understand
/// a document's structure.
public struct DocxInspector: Sendable {

    // MARK: - Result Types

    /// High-level document information.
    public struct DocumentInfo: Codable, Sendable {
        public let title: String?
        public let author: String?
        public let paragraphs: Int
        public let tables: Int
        public let images: Int
        public let headings: Int
    }

    /// A single heading with its level and text.
    public struct HeadingInfo: Codable, Sendable {
        public let level: Int
        public let text: String
    }

    /// Summary of a table in the document.
    public struct TableInfo: Codable, Sendable {
        public let rows: Int
        public let columns: Int
        public let preview: [[String]]
    }

    // MARK: - Errors

    public enum InspectorError: Error, Sendable {
        case fileNotFound(String)
        case invalidDocx(String)
        case missingDocumentXML
    }

    // MARK: - Public API

    /// Inspects a `.docx` file and returns high-level document information.
    ///
    /// - Parameter path: The file system path to the `.docx` file.
    /// - Returns: A ``DocumentInfo`` with counts of paragraphs, tables, images, and headings.
    public static func inspect(at path: String) throws -> DocumentInfo {
        let (documentXml, coreXml, relsXml, entries) = try readDocxComponents(at: path)

        let paragraphs = DocxXMLParser.extractParagraphs(from: documentXml)
        let headings = DocxXMLParser.extractHeadings(from: documentXml)
        let tables = DocxXMLParser.extractTables(from: documentXml)

        // Count images by looking at relationship IDs and cross-referencing
        let imageRIds = DocxXMLParser.extractImages(from: documentXml)
        let imageCount: Int
        if let relsContent = relsXml {
            let relationships = DocxXMLParser.extractRelationships(from: relsContent)
            let imageRels = relationships.filter { rel in
                rel.type.contains("image") || rel.type.contains("Image")
            }
            // Count unique image references that appear in the document
            let imageRelIds = Set(imageRels.map(\.id))
            let matchedCount = imageRIds.filter { imageRelIds.contains($0) }.count
            // If no rels match but we have rIds, count the rIds
            imageCount = matchedCount > 0 ? matchedCount : imageRIds.count
        } else {
            imageCount = imageRIds.count
        }
        _ = entries // suppress unused warning

        // Extract title/author from core properties
        var title: String?
        var author: String?
        if let core = coreXml {
            title = DocxXMLParser.extractTitle(from: core)
            author = DocxXMLParser.extractAuthor(from: core)
        }

        return DocumentInfo(
            title: title,
            author: author,
            paragraphs: paragraphs.count,
            tables: tables.count,
            images: imageCount,
            headings: headings.count
        )
    }

    /// Extracts the document outline (headings with their levels).
    ///
    /// - Parameter path: The file system path to the `.docx` file.
    /// - Returns: An array of ``HeadingInfo`` in document order.
    public static func outline(at path: String) throws -> [HeadingInfo] {
        let documentXml = try readDocumentXml(at: path)
        let headings = DocxXMLParser.extractHeadings(from: documentXml)

        return headings.map { HeadingInfo(level: $0.level, text: $0.text) }
    }

    /// Extracts all text content from the document, joining paragraphs with newlines.
    ///
    /// - Parameter path: The file system path to the `.docx` file.
    /// - Returns: The full text content of the document.
    public static func extractText(at path: String) throws -> String {
        let documentXml = try readDocumentXml(at: path)
        let paragraphs = DocxXMLParser.extractParagraphs(from: documentXml)

        return paragraphs.map(\.text).joined(separator: "\n")
    }

    /// Extracts all tables from the document.
    ///
    /// - Parameter path: The file system path to the `.docx` file.
    /// - Returns: An array of ``TableInfo`` with row/column counts and a preview.
    public static func extractTables(at path: String) throws -> [TableInfo] {
        let documentXml = try readDocumentXml(at: path)
        let tables = DocxXMLParser.extractTables(from: documentXml)

        return tables.map { table in
            let rowCount = table.count
            let columnCount = table.map(\.count).max() ?? 0
            // Preview: first 5 rows
            let previewRows = Array(table.prefix(5))
            return TableInfo(rows: rowCount, columns: columnCount, preview: previewRows)
        }
    }

    // MARK: - Private Helpers

    /// Reads and returns the `word/document.xml` content from a `.docx` file.
    private static func readDocumentXml(at path: String) throws -> String {
        let data = try readFileData(at: path)
        let entries = try DocxZIPReader.readEntries(from: data)

        guard let docEntry = entries.first(where: { $0.path == "word/document.xml" }) else {
            throw InspectorError.missingDocumentXML
        }

        guard let xml = String(data: docEntry.data, encoding: .utf8) else {
            throw InspectorError.invalidDocx("Cannot decode word/document.xml as UTF-8")
        }

        return xml
    }

    /// Reads the main document components from a `.docx` file.
    private static func readDocxComponents(at path: String) throws
        -> (documentXml: String, coreXml: String?, relsXml: String?, entries: [DocxZIPReader.Entry])
    {
        let data = try readFileData(at: path)
        let entries = try DocxZIPReader.readEntries(from: data)

        guard let docEntry = entries.first(where: { $0.path == "word/document.xml" }) else {
            throw InspectorError.missingDocumentXML
        }

        guard let documentXml = String(data: docEntry.data, encoding: .utf8) else {
            throw InspectorError.invalidDocx("Cannot decode word/document.xml as UTF-8")
        }

        let coreXml: String?
        if let coreEntry = entries.first(where: { $0.path == "docProps/core.xml" }) {
            coreXml = String(data: coreEntry.data, encoding: .utf8)
        } else {
            coreXml = nil
        }

        let relsXml: String?
        if let relsEntry = entries.first(where: { $0.path == "word/_rels/document.xml.rels" }) {
            relsXml = String(data: relsEntry.data, encoding: .utf8)
        } else {
            relsXml = nil
        }

        return (documentXml, coreXml, relsXml, entries)
    }

    /// Reads raw file data from disk.
    private static func readFileData(at path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw InspectorError.fileNotFound(path)
        }
    }
}

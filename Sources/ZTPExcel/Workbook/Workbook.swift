// Workbook.swift
// ZTPExcel – Top-level workbook model.

import Foundation

/// An in-memory representation of an Excel workbook.
public struct Workbook: Codable, Sendable {
    /// Optional document title (stored in docProps/core.xml).
    public var title: String?

    /// Optional document author.
    public var author: String?

    /// The ordered list of worksheets (tabs).
    public var sheets: [Worksheet]

    public init(
        title: String? = nil,
        author: String? = nil,
        sheets: [Worksheet] = []
    ) {
        self.title = title
        self.author = author
        self.sheets = sheets
    }
}

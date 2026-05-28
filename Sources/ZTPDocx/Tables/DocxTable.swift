// DocxTable.swift
// ZTPDocx – Table data model

import Foundation

public struct DocxTable: Codable, Sendable, Equatable {
    public let headers: [String]?
    public let rows: [[String]]
    public let style: String?
    public let columnWidths: [Int]?

    public init(
        headers: [String]? = nil,
        rows: [[String]],
        style: String? = nil,
        columnWidths: [Int]? = nil
    ) {
        self.headers = headers
        self.rows = rows
        self.style = style
        self.columnWidths = columnWidths
    }

    /// The number of columns, derived from the maximum of headers count and the widest row.
    public var columnCount: Int {
        let headerCount = headers?.count ?? 0
        let maxRowCount = rows.map(\.count).max() ?? 0
        return max(headerCount, maxRowCount)
    }
}

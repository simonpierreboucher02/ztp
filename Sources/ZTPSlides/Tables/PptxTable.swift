import Foundation

/// A table element that can be placed on a slide.
public struct PptxTable: Codable, Sendable, Equatable {
    /// Optional header row.
    public let headers: [String]?
    /// Data rows. Each inner array is one row of cell values.
    public let rows: [[String]]
    /// Optional style identifier.
    public let style: String?

    public init(headers: [String]? = nil, rows: [[String]], style: String? = nil) {
        self.headers = headers
        self.rows = rows
        self.style = style
    }

    /// The number of columns, derived from headers or the first data row.
    public var columnCount: Int {
        if let headers = headers, !headers.isEmpty {
            return headers.count
        }
        return rows.first?.count ?? 0
    }
}

// Cell.swift
// ZTPExcel – A single cell in a worksheet.

import Foundation

/// Represents one cell in a worksheet, combining its address, value, and
/// an optional named style reference.
public struct Cell: Codable, Sendable {
    /// The cell's position (e.g. A1).
    public let address: CellAddress

    /// The cell's value (string, number, formula, etc.).
    public var value: CellValue

    /// An optional reference to a named style defined in the style registry.
    public var styleName: String?

    public init(
        address: CellAddress,
        value: CellValue,
        styleName: String? = nil
    ) {
        self.address = address
        self.value = value
        self.styleName = styleName
    }
}

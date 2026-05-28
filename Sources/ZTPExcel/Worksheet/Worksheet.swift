// Worksheet.swift
// ZTPExcel – A single worksheet (tab) inside a workbook.

import Foundation

/// A named worksheet containing an ordered collection of cells.
public struct Worksheet: Codable, Sendable {
    /// The tab name shown in Excel.
    public var name: String

    /// Cells belonging to this sheet.
    public var cells: [Cell]

    public init(name: String, cells: [Cell] = []) {
        self.name = name
        self.cells = cells
    }
}

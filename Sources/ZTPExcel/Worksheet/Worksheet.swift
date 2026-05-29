// Worksheet.swift
// ZTPExcel – A single worksheet (tab) inside a workbook.

import Foundation

/// A column-width directive: columns `min`…`max` (1-based) set to `width`
/// (in Excel character units).
public struct ColumnWidth: Codable, Sendable, Equatable {
    public var min: Int
    public var max: Int
    public var width: Double
    public init(min: Int, max: Int, width: Double) {
        self.min = min; self.max = max; self.width = width
    }
}

/// A data-validation rule applied to a cell range.
public struct DataValidation: Codable, Sendable, Equatable {
    public var sqref: String       // target range, e.g. "A2:A100"
    public var type: String        // "list", "whole", "decimal"
    public var formula1: String    // list: "\"X,Y,Z\"" ; numeric: min
    public var formula2: String?   // numeric: max (operator "between")
    public init(sqref: String, type: String, formula1: String, formula2: String? = nil) {
        self.sqref = sqref; self.type = type; self.formula1 = formula1; self.formula2 = formula2
    }
}

/// A self-contained conditional-format rule (data bar or color scale). These
/// need no differential-format (`dxf`) entries in styles.xml, keeping the
/// feature contained to the worksheet part.
public struct ConditionalFormat: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case dataBar, colorScale }
    public var sqref: String
    public var kind: Kind
    /// Data-bar fill color (hex, no '#').
    public var barColor: String?
    /// Color-scale stops (2 or 3 hex colors, low→high).
    public var scaleColors: [String]?
    public init(sqref: String, kind: Kind, barColor: String? = nil, scaleColors: [String]? = nil) {
        self.sqref = sqref; self.kind = kind; self.barColor = barColor; self.scaleColors = scaleColors
    }
}

/// A threaded/legacy cell comment (note).
public struct CellComment: Codable, Sendable, Equatable {
    public var ref: String       // cell, e.g. "B2"
    public var author: String
    public var text: String
    public init(ref: String, author: String = "ZTP", text: String) {
        self.ref = ref; self.author = author; self.text = text
    }
}

/// A named worksheet containing an ordered collection of cells.
public struct Worksheet: Codable, Sendable {
    /// The tab name shown in Excel.
    public var name: String

    /// Cells belonging to this sheet.
    public var cells: [Cell]

    /// Merged-cell ranges in A1 notation (e.g. "A1:C1").
    public var merges: [String]

    /// Column-width directives.
    public var columnWidths: [ColumnWidth]

    /// Number of top rows to freeze (0 = none).
    public var freezeRows: Int

    /// Number of left columns to freeze (0 = none).
    public var freezeColumns: Int

    /// Data-validation rules (dropdowns, numeric ranges).
    public var dataValidations: [DataValidation]

    /// Conditional-format rules (data bars / color scales).
    public var conditionalFormats: [ConditionalFormat]

    /// Cell comments (notes).
    public var comments: [CellComment]

    public init(
        name: String,
        cells: [Cell] = [],
        merges: [String] = [],
        columnWidths: [ColumnWidth] = [],
        freezeRows: Int = 0,
        freezeColumns: Int = 0,
        dataValidations: [DataValidation] = [],
        conditionalFormats: [ConditionalFormat] = [],
        comments: [CellComment] = []
    ) {
        self.name = name
        self.cells = cells
        self.merges = merges
        self.columnWidths = columnWidths
        self.freezeRows = freezeRows
        self.freezeColumns = freezeColumns
        self.dataValidations = dataValidations
        self.conditionalFormats = conditionalFormats
        self.comments = comments
    }
}

// WorkbookSpec.swift
// ZTPExcel – JSON spec decoder for ZTP Excel input files.

import Foundation

// MARK: - Spec errors

/// Errors thrown when converting a ``WorkbookSpec`` to internal models.
public enum SpecError: Error, Sendable {
    case invalidCellAddress(String)
    case unsupportedVersion(String)
}

// MARK: - WorkbookSpec

/// Root structure matching the `ztp-excel/0.1` JSON input format.
///
/// ```json
/// {
///   "version": "ztp-excel/0.1",
///   "workbook": { "title": "...", "author": "..." },
///   "sheets": [ ... ],
///   "styles": { "header": { ... } }
/// }
/// ```
public struct WorkbookSpec: Codable, Sendable {
    public var version: String
    public var workbook: WorkbookMeta?
    public var sheets: [SheetSpec]
    public var styles: [String: StyleSpec]?

    public init(
        version: String = "ztp-excel/0.1",
        workbook: WorkbookMeta? = nil,
        sheets: [SheetSpec] = [],
        styles: [String: StyleSpec]? = nil
    ) {
        self.version = version
        self.workbook = workbook
        self.sheets = sheets
        self.styles = styles
    }
}

// MARK: - WorkbookMeta

/// Metadata for the workbook (title, author).
public struct WorkbookMeta: Codable, Sendable {
    public var title: String?
    public var author: String?

    public init(title: String? = nil, author: String? = nil) {
        self.title = title
        self.author = author
    }
}

// MARK: - SheetSpec

/// A sheet definition inside the JSON spec.
public struct SheetSpec: Codable, Sendable {
    public var name: String
    public var cells: [CellSpec]
    /// Merged-cell ranges in A1 notation, e.g. ["A1:C1"].
    public var merges: [String]?
    /// Column-width directives.
    public var columns: [ColumnSpec]?
    /// Frozen panes.
    public var freeze: FreezeSpec?
    /// Data-validation rules (dropdowns / numeric ranges).
    public var validations: [ValidationSpec]?
    /// Conditional-format rules (data bars / color scales).
    public var conditionalFormats: [ConditionalFormatSpec]?
    /// Cell comments (notes).
    public var comments: [CommentSpec]?

    public init(
        name: String,
        cells: [CellSpec] = [],
        merges: [String]? = nil,
        columns: [ColumnSpec]? = nil,
        freeze: FreezeSpec? = nil,
        validations: [ValidationSpec]? = nil,
        conditionalFormats: [ConditionalFormatSpec]? = nil,
        comments: [CommentSpec]? = nil
    ) {
        self.name = name
        self.cells = cells
        self.merges = merges
        self.columns = columns
        self.freeze = freeze
        self.validations = validations
        self.conditionalFormats = conditionalFormats
        self.comments = comments
    }

    enum CodingKeys: String, CodingKey {
        case name, cells, merges, columns, freeze, validations, comments
        case conditionalFormats = "conditional_formats"
    }
}

/// A conditional-format directive: `type: "data_bar"` (with `color`) or
/// `"color_scale"` (with `colors`).
public struct ConditionalFormatSpec: Codable, Sendable {
    public var range: String
    public var type: String?      // "data_bar" (default) | "color_scale"
    public var color: String?
    public var colors: [String]?
}

/// A cell-comment directive.
public struct CommentSpec: Codable, Sendable {
    public var ref: String
    public var text: String
    public var author: String?
}

/// A data-validation directive. For `type: "list"` provide `values`; for
/// `"whole"`/`"decimal"` provide `min`/`max`.
public struct ValidationSpec: Codable, Sendable {
    public var range: String
    public var type: String?         // "list" (default), "whole", "decimal"
    public var values: [String]?
    public var min: Double?
    public var max: Double?
}

/// A column-width directive. Either `column` (a letter like "A") or a
/// `min`/`max` 1-based range, plus a `width` in Excel character units.
public struct ColumnSpec: Codable, Sendable {
    public var column: String?
    public var min: Int?
    public var max: Int?
    public var width: Double
}

/// Frozen-pane directive: freeze the top `rows` and/or left `columns`.
public struct FreezeSpec: Codable, Sendable {
    public var rows: Int?
    public var columns: Int?
}

// MARK: - CellSpec

/// A single cell as it appears in the JSON spec.
///
/// The `value` field is a flexible JSON type that can be a string, number,
/// boolean, or null. The optional `formula` field takes precedence over `value`
/// when present.
public struct CellSpec: Sendable, Equatable {
    /// A1-style address string (e.g. "B7").
    public var address: String

    /// The literal value — string, number, bool, or nil.
    public var value: FlexibleValue?

    /// An optional named style reference (e.g. "header").
    public var style: String?

    /// An optional number format string (e.g. "currency").
    public var format: String?

    /// An optional formula string (e.g. "B2*1.10").
    public var formula: String?

    public init(
        address: String,
        value: FlexibleValue? = nil,
        style: String? = nil,
        format: String? = nil,
        formula: String? = nil
    ) {
        self.address = address
        self.value = value
        self.style = style
        self.format = format
        self.formula = formula
    }
}

// MARK: - FlexibleValue

/// A JSON value that can be a string, number (int or double), boolean, or null.
public enum FlexibleValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
}

extension FlexibleValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        // Try bool before numeric — JSON booleans can sometimes decode as Int.
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
            return
        }
        if let i = try? container.decode(Int.self) {
            self = .int(i)
            return
        }
        if let d = try? container.decode(Double.self) {
            self = .double(d)
            return
        }
        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }
        throw DecodingError.typeMismatch(
            FlexibleValue.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "Unsupported JSON value type")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i):    try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b):   try container.encode(b)
        case .null:          try container.encodeNil()
        }
    }
}

// MARK: - CellSpec Codable

extension CellSpec: Codable {
    private enum CodingKeys: String, CodingKey {
        case address, value, style, format, formula
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try container.decode(String.self, forKey: .address)
        self.value   = try container.decodeIfPresent(FlexibleValue.self, forKey: .value)
        self.style   = try container.decodeIfPresent(String.self, forKey: .style)
        self.format  = try container.decodeIfPresent(String.self, forKey: .format)
        self.formula = try container.decodeIfPresent(String.self, forKey: .formula)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(style, forKey: .style)
        try container.encodeIfPresent(format, forKey: .format)
        try container.encodeIfPresent(formula, forKey: .formula)
    }
}

// MARK: - StyleSpec

/// A style definition in the JSON spec, matching the `styles` dictionary.
public struct StyleSpec: Codable, Sendable, Equatable {
    public var font: FontStyleSpec?
    public var fill: FillStyleSpec?
    public var alignment: AlignmentStyleSpec?
    public var numberFormat: String?

    public init(
        font: FontStyleSpec? = nil,
        fill: FillStyleSpec? = nil,
        alignment: AlignmentStyleSpec? = nil,
        numberFormat: String? = nil
    ) {
        self.font = font
        self.fill = fill
        self.alignment = alignment
        self.numberFormat = numberFormat
    }
}

public struct FontStyleSpec: Codable, Sendable, Equatable {
    public var bold: Bool?
    public var italic: Bool?
    public var size: Double?
    public var color: String?

    public init(bold: Bool? = nil, italic: Bool? = nil, size: Double? = nil, color: String? = nil) {
        self.bold = bold
        self.italic = italic
        self.size = size
        self.color = color
    }
}

public struct FillStyleSpec: Codable, Sendable, Equatable {
    public var color: String?

    public init(color: String? = nil) {
        self.color = color
    }
}

public struct AlignmentStyleSpec: Codable, Sendable, Equatable {
    public var horizontal: String?
    public var vertical: String?
    public var wrapText: Bool?

    public init(horizontal: String? = nil, vertical: String? = nil, wrapText: Bool? = nil) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.wrapText = wrapText
    }
}

// MARK: - Conversion helpers

extension WorkbookSpec {

    /// Converts the spec into an internal ``Workbook`` model.
    ///
    /// - Throws: ``SpecError/invalidCellAddress(_:)`` if any cell address
    ///   string cannot be parsed.
    public func toWorkbook() throws -> Workbook {
        var worksheets: [Worksheet] = []

        for sheetSpec in sheets {
            var cells: [Cell] = []

            for cellSpec in sheetSpec.cells {
                guard let addr = CellAddress(string: cellSpec.address) else {
                    throw SpecError.invalidCellAddress(cellSpec.address)
                }

                let cellValue: CellValue
                if let formula = cellSpec.formula {
                    cellValue = .formula(formula)
                } else if let flexVal = cellSpec.value {
                    cellValue = flexVal.toCellValue()
                } else {
                    cellValue = .blank
                }

                let cell = Cell(
                    address: addr,
                    value: cellValue,
                    styleName: cellSpec.style
                )
                cells.append(cell)
            }

            // Column widths
            var columnWidths: [ColumnWidth] = []
            for col in sheetSpec.columns ?? [] {
                let lo: Int
                let hi: Int
                if let letter = col.column {
                    let n = CellAddress.columnNumber(from: letter.uppercased())
                    lo = n; hi = n
                } else {
                    lo = col.min ?? 1
                    hi = col.max ?? lo
                }
                if lo >= 1 && hi >= lo && col.width > 0 {
                    columnWidths.append(ColumnWidth(min: lo, max: hi, width: col.width))
                }
            }

            // Data validations
            var validations: [DataValidation] = []
            for v in sheetSpec.validations ?? [] {
                let type = v.type ?? "list"
                if type == "list" {
                    let vals = (v.values ?? []).map { $0.replacingOccurrences(of: "\"", with: "") }
                    guard !vals.isEmpty else { continue }
                    validations.append(DataValidation(
                        sqref: v.range, type: "list",
                        formula1: "\"\(vals.joined(separator: ","))\""
                    ))
                } else {
                    // numeric range (whole/decimal)
                    let fmt: (Double) -> String = { $0 == $0.rounded() ? String(Int($0)) : String($0) }
                    let lo = v.min.map(fmt) ?? "0"
                    let hi = v.max.map(fmt)
                    validations.append(DataValidation(
                        sqref: v.range, type: type, formula1: lo, formula2: hi
                    ))
                }
            }

            // Conditional formats
            var conditionalFormats: [ConditionalFormat] = []
            for cf in sheetSpec.conditionalFormats ?? [] {
                switch (cf.type ?? "data_bar") {
                case "color_scale":
                    conditionalFormats.append(ConditionalFormat(
                        sqref: cf.range, kind: .colorScale, scaleColors: cf.colors
                    ))
                default:
                    conditionalFormats.append(ConditionalFormat(
                        sqref: cf.range, kind: .dataBar, barColor: cf.color
                    ))
                }
            }

            // Comments
            let comments: [CellComment] = (sheetSpec.comments ?? []).map {
                CellComment(ref: $0.ref, author: $0.author ?? "ZTP", text: $0.text)
            }

            worksheets.append(Worksheet(
                name: sheetSpec.name,
                cells: cells,
                merges: sheetSpec.merges ?? [],
                columnWidths: columnWidths,
                freezeRows: max(0, sheetSpec.freeze?.rows ?? 0),
                freezeColumns: max(0, sheetSpec.freeze?.columns ?? 0),
                dataValidations: validations,
                conditionalFormats: conditionalFormats,
                comments: comments
            ))
        }

        return Workbook(
            title: workbook?.title,
            author: workbook?.author,
            sheets: worksheets
        )
    }

    /// Builds a mapping of style names to ``CellStyle`` from the spec's
    /// `styles` dictionary.
    public func toStyleMap() -> [String: CellStyle] {
        guard let specStyles = styles else { return [:] }

        var map: [String: CellStyle] = [:]
        for (name, spec) in specStyles {
            map[name] = spec.toCellStyle()
        }
        return map
    }
}

// MARK: - Internal conversion helpers

extension FlexibleValue {
    /// Converts the flexible JSON value to a ``CellValue``.
    func toCellValue() -> CellValue {
        switch self {
        case .string(let s): return .string(s)
        case .int(let i):    return .integer(i)
        case .double(let d): return .number(d)
        case .bool(let b):   return .boolean(b)
        case .null:          return .blank
        }
    }
}

extension StyleSpec {
    /// Converts a spec-level style to the internal ``CellStyle`` model.
    func toCellStyle() -> CellStyle {
        let fontStyle: FontStyle? = font.map {
            FontStyle(bold: $0.bold, italic: $0.italic, size: $0.size, color: $0.color)
        }
        let fillStyle: FillStyle? = fill.map {
            FillStyle(color: $0.color)
        }
        let alignStyle: AlignmentStyle? = alignment.map {
            AlignmentStyle(
                horizontal: $0.horizontal.flatMap { HorizontalAlignment(rawValue: $0) },
                vertical: $0.vertical.flatMap { VerticalAlignment(rawValue: $0) },
                wrapText: $0.wrapText
            )
        }

        return CellStyle(
            font: fontStyle,
            fill: fillStyle,
            numberFormat: numberFormat,
            alignment: alignStyle
        )
    }
}

// CellStyle.swift
// ZTPExcel – Style definitions for cells.

import Foundation

/// Visual style applied to a worksheet cell.
public struct CellStyle: Codable, Sendable, Equatable, Hashable {
    public var font: FontStyle?
    public var fill: FillStyle?
    public var numberFormat: String?
    public var alignment: AlignmentStyle?

    public init(
        font: FontStyle? = nil,
        fill: FillStyle? = nil,
        numberFormat: String? = nil,
        alignment: AlignmentStyle? = nil
    ) {
        self.font = font
        self.fill = fill
        self.numberFormat = numberFormat
        self.alignment = alignment
    }
}

// MARK: - FontStyle

/// Font properties for a cell style.
public struct FontStyle: Codable, Sendable, Equatable, Hashable {
    public var bold: Bool?
    public var italic: Bool?
    public var size: Double?
    public var color: String?  // hex colour, e.g. "FF0000"

    public init(
        bold: Bool? = nil,
        italic: Bool? = nil,
        size: Double? = nil,
        color: String? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.size = size
        self.color = color
    }
}

// MARK: - FillStyle

/// Background fill for a cell style.
public struct FillStyle: Codable, Sendable, Equatable, Hashable {
    public var color: String?  // hex colour, e.g. "4472C4"

    public init(color: String? = nil) {
        self.color = color
    }
}

// MARK: - AlignmentStyle

/// Text alignment within a cell.
public struct AlignmentStyle: Codable, Sendable, Equatable, Hashable {

    /// Horizontal alignment (e.g. "left", "center", "right").
    public var horizontal: HorizontalAlignment?

    /// Vertical alignment (e.g. "top", "center", "bottom").
    public var vertical: VerticalAlignment?

    /// Whether text wraps within the cell.
    public var wrapText: Bool?

    public init(
        horizontal: HorizontalAlignment? = nil,
        vertical: VerticalAlignment? = nil,
        wrapText: Bool? = nil
    ) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.wrapText = wrapText
    }
}

// MARK: - Alignment enums

public enum HorizontalAlignment: String, Codable, Sendable, Equatable, Hashable {
    case left, center, right, fill, justify, general
}

public enum VerticalAlignment: String, Codable, Sendable, Equatable, Hashable {
    case top, center, bottom, justify, distributed
}

// DocxStyle.swift
// ZTPDocx – Style definitions for fonts and paragraphs

import Foundation

// MARK: - DocxStyle

public struct DocxStyle: Codable, Sendable, Equatable, Hashable {
    public var font: DocxFontStyle?
    public var paragraph: DocxParagraphStyle?

    public init(
        font: DocxFontStyle? = nil,
        paragraph: DocxParagraphStyle? = nil
    ) {
        self.font = font
        self.paragraph = paragraph
    }
}

// MARK: - DocxFontStyle

public struct DocxFontStyle: Codable, Sendable, Equatable, Hashable {
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var size: Double?     // in points
    public var family: String?   // font family name
    public var color: String?    // hex color

    public init(
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil,
        size: Double? = nil,
        family: String? = nil,
        color: String? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.size = size
        self.family = family
        self.color = color
    }
}

// MARK: - DocxParagraphStyle

public struct DocxParagraphStyle: Codable, Sendable, Equatable, Hashable {
    public var alignment: ParagraphAlignment?
    public var spacingBefore: Int?  // in points
    public var spacingAfter: Int?   // in points
    public var lineSpacing: Double?

    public init(
        alignment: ParagraphAlignment? = nil,
        spacingBefore: Int? = nil,
        spacingAfter: Int? = nil,
        lineSpacing: Double? = nil
    ) {
        self.alignment = alignment
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.lineSpacing = lineSpacing
    }
}

// DocxRun.swift
// ZTPDocx – A contiguous piece of text with uniform formatting

import Foundation

public struct DocxRun: Codable, Sendable, Equatable {
    public let text: String
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var fontSize: Double?
    public var fontFamily: String?
    public var color: String?  // hex e.g. "FF0000"

    public init(
        text: String,
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil,
        fontSize: Double? = nil,
        fontFamily: String? = nil,
        color: String? = nil
    ) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.color = color
    }
}

// DocumentSpec.swift
// ZTPDocx – JSON specification decoder for ZTP-DOCX document format

import Foundation

// MARK: - Errors

public enum DocxSpecError: Error, Sendable {
    case invalidElementType(String)
    case missingRequiredField(String)
    case unsupportedVersion(String)
}

// MARK: - DocumentSpec

public struct DocumentSpec: Codable, Sendable, Equatable {
    public let version: String
    public let document: DocumentMeta?
    public let sections: [SectionSpec]
    public let styles: [String: DocxStyleSpec]?

    public init(
        version: String,
        document: DocumentMeta? = nil,
        sections: [SectionSpec],
        styles: [String: DocxStyleSpec]? = nil
    ) {
        self.version = version
        self.document = document
        self.sections = sections
        self.styles = styles
    }
}

// MARK: - DocumentMeta

public struct DocumentMeta: Codable, Sendable, Equatable {
    public let title: String?
    public let author: String?

    public init(title: String? = nil, author: String? = nil) {
        self.title = title
        self.author = author
    }
}

// MARK: - SectionSpec

public struct SectionSpec: Codable, Sendable, Equatable {
    public let elements: [ElementSpec]
    public let header: String?
    public let footer: String?

    public init(
        elements: [ElementSpec],
        header: String? = nil,
        footer: String? = nil
    ) {
        self.elements = elements
        self.header = header
        self.footer = footer
    }
}

// MARK: - RunSpec

public struct RunSpec: Codable, Sendable, Equatable {
    public let text: String
    public let bold: Bool?
    public let italic: Bool?
    public let underline: Bool?
    public let fontSize: Double?
    public let fontFamily: String?
    public let color: String?
    /// Optional hyperlink target URL; makes this run a clickable link.
    public let link: String?

    public init(
        text: String,
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil,
        fontSize: Double? = nil,
        fontFamily: String? = nil,
        color: String? = nil,
        link: String? = nil
    ) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.color = color
        self.link = link
    }
}

// MARK: - ElementSpec

public enum ElementSpec: Sendable, Equatable {
    case heading(level: Int, text: String, style: String?)
    case paragraph(text: String?, runs: [RunSpec]?, style: String?, alignment: String?)
    case bulletList(items: [DocxListItem])
    case numberedList(items: [DocxListItem])
    case table(headers: [String]?, rows: [[String]], style: String?, columnWidths: [Int]?)
    case image(path: String, width: Int?, height: Int?, caption: String?)
    case pageBreak
    case horizontalRule
}

extension ElementSpec: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case level, text, style, alignment
        case runs
        case items
        case headers, rows, columnWidths
        case path, width, height, caption
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "heading":
            let level = try container.decode(Int.self, forKey: .level)
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .heading(level: level, text: text, style: style)

        case "paragraph":
            let text = try container.decodeIfPresent(String.self, forKey: .text)
            let runs = try container.decodeIfPresent([RunSpec].self, forKey: .runs)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            let alignment = try container.decodeIfPresent(String.self, forKey: .alignment)
            self = .paragraph(text: text, runs: runs, style: style, alignment: alignment)

        case "bullet_list":
            let items = try container.decode([DocxListItem].self, forKey: .items)
            self = .bulletList(items: items)

        case "numbered_list":
            let items = try container.decode([DocxListItem].self, forKey: .items)
            self = .numberedList(items: items)

        case "table":
            let headers = try container.decodeIfPresent([String].self, forKey: .headers)
            let rows = try container.decode([[String]].self, forKey: .rows)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            let columnWidths = try container.decodeIfPresent([Int].self, forKey: .columnWidths)
            self = .table(headers: headers, rows: rows, style: style, columnWidths: columnWidths)

        case "image":
            let path = try container.decode(String.self, forKey: .path)
            let width = try container.decodeIfPresent(Int.self, forKey: .width)
            let height = try container.decodeIfPresent(Int.self, forKey: .height)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(path: path, width: width, height: height, caption: caption)

        case "page_break":
            self = .pageBreak

        case "horizontal_rule":
            self = .horizontalRule

        default:
            throw DocxSpecError.invalidElementType(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .heading(level, text, style):
            try container.encode("heading", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(style, forKey: .style)

        case let .paragraph(text, runs, style, alignment):
            try container.encode("paragraph", forKey: .type)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(runs, forKey: .runs)
            try container.encodeIfPresent(style, forKey: .style)
            try container.encodeIfPresent(alignment, forKey: .alignment)

        case let .bulletList(items):
            try container.encode("bullet_list", forKey: .type)
            try container.encode(items, forKey: .items)

        case let .numberedList(items):
            try container.encode("numbered_list", forKey: .type)
            try container.encode(items, forKey: .items)

        case let .table(headers, rows, style, columnWidths):
            try container.encode("table", forKey: .type)
            try container.encodeIfPresent(headers, forKey: .headers)
            try container.encode(rows, forKey: .rows)
            try container.encodeIfPresent(style, forKey: .style)
            try container.encodeIfPresent(columnWidths, forKey: .columnWidths)

        case let .image(path, width, height, caption):
            try container.encode("image", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
            try container.encodeIfPresent(caption, forKey: .caption)

        case .pageBreak:
            try container.encode("page_break", forKey: .type)

        case .horizontalRule:
            try container.encode("horizontal_rule", forKey: .type)
        }
    }
}

// MARK: - Style Specs

public struct DocxStyleSpec: Codable, Sendable, Equatable {
    public let font: DocxFontStyleSpec?
    public let paragraph: DocxParagraphStyleSpec?

    public init(
        font: DocxFontStyleSpec? = nil,
        paragraph: DocxParagraphStyleSpec? = nil
    ) {
        self.font = font
        self.paragraph = paragraph
    }
}

public struct DocxFontStyleSpec: Codable, Sendable, Equatable {
    public let bold: Bool?
    public let italic: Bool?
    public let underline: Bool?
    public let size: Double?
    public let family: String?
    public let color: String?

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

public struct DocxParagraphStyleSpec: Codable, Sendable, Equatable {
    public let alignment: String?
    public let spacingBefore: Int?
    public let spacingAfter: Int?
    public let lineSpacing: Double?

    public init(
        alignment: String? = nil,
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

// MARK: - Conversions

extension DocumentSpec {

    /// Convert the spec to a `DocxDocument` model.
    public func toDocument() throws -> DocxDocument {
        guard version.hasPrefix("ztp-docx/") else {
            throw DocxSpecError.unsupportedVersion(version)
        }

        let docxSections = try sections.map { sectionSpec -> DocxSection in
            let elements = try sectionSpec.elements.map { elementSpec -> DocxElement in
                try elementSpec.toElement()
            }
            return DocxSection(
                elements: elements,
                header: sectionSpec.header,
                footer: sectionSpec.footer
            )
        }

        return DocxDocument(
            title: document?.title,
            author: document?.author,
            sections: docxSections
        )
    }

    /// Convert the spec styles to a style map.
    public func toStyleMap() -> [String: DocxStyle] {
        guard let specStyles = styles else { return [:] }
        var map: [String: DocxStyle] = [:]
        for (name, specStyle) in specStyles {
            map[name] = specStyle.toDocxStyle()
        }
        return map
    }
}

// MARK: - ElementSpec -> DocxElement

extension ElementSpec {

    func toElement() throws -> DocxElement {
        switch self {
        case let .heading(level, text, style):
            return .heading(level: level, text: text, style: style)

        case let .paragraph(text, runs, style, alignmentStr):
            let alignment: ParagraphAlignment? = alignmentStr.flatMap { ParagraphAlignment(rawValue: $0) }
            let docxRuns: [DocxRun]

            if let runs = runs, !runs.isEmpty {
                docxRuns = runs.map { $0.toDocxRun() }
            } else if let text = text {
                docxRuns = [DocxRun(text: text)]
            } else {
                throw DocxSpecError.missingRequiredField("paragraph requires 'text' or 'runs'")
            }

            return .paragraph(runs: docxRuns, style: style, alignment: alignment)

        case let .bulletList(items):
            return .bulletList(items: items)

        case let .numberedList(items):
            return .numberedList(items: items)

        case let .table(headers, rows, style, columnWidths):
            return .table(DocxTable(headers: headers, rows: rows, style: style, columnWidths: columnWidths))

        case let .image(path, width, height, caption):
            return .image(DocxImage(path: path, width: width, height: height, caption: caption))

        case .pageBreak:
            return .pageBreak

        case .horizontalRule:
            return .horizontalRule
        }
    }
}

// MARK: - RunSpec -> DocxRun

extension RunSpec {

    func toDocxRun() -> DocxRun {
        DocxRun(
            text: text,
            bold: bold,
            italic: italic,
            underline: underline,
            fontSize: fontSize,
            fontFamily: fontFamily,
            color: color,
            link: link
        )
    }
}

// MARK: - StyleSpec -> DocxStyle

extension DocxStyleSpec {

    func toDocxStyle() -> DocxStyle {
        DocxStyle(
            font: font?.toDocxFontStyle(),
            paragraph: paragraph?.toDocxParagraphStyle()
        )
    }
}

extension DocxFontStyleSpec {

    func toDocxFontStyle() -> DocxFontStyle {
        DocxFontStyle(
            bold: bold,
            italic: italic,
            underline: underline,
            size: size,
            family: family,
            color: color
        )
    }
}

extension DocxParagraphStyleSpec {

    func toDocxParagraphStyle() -> DocxParagraphStyle {
        DocxParagraphStyle(
            alignment: alignment.flatMap { ParagraphAlignment(rawValue: $0) },
            spacingBefore: spacingBefore,
            spacingAfter: spacingAfter,
            lineSpacing: lineSpacing
        )
    }
}

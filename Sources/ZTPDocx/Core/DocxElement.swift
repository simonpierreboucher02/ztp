// DocxElement.swift
// ZTPDocx – Core block-level element types

import Foundation

// MARK: - ParagraphAlignment

public enum ParagraphAlignment: String, Codable, Sendable, Equatable {
    case left
    case center
    case right
    case justify
    case both
}

// MARK: - DocxElement

public enum DocxElement: Sendable, Equatable {
    case heading(level: Int, text: String, style: String?)
    case paragraph(runs: [DocxRun], style: String?, alignment: ParagraphAlignment?)
    case bulletList(items: [String])
    case numberedList(items: [String])
    case table(DocxTable)
    case image(DocxImage)
    case pageBreak
    case horizontalRule
}

// MARK: - DocxElement + Codable

extension DocxElement: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case level, text, style, alignment
        case runs
        case items
        case headers, rows, columnWidths
        case path, width, height, caption
    }

    private enum ElementType: String, Codable {
        case heading
        case paragraph
        case bulletList = "bullet_list"
        case numberedList = "numbered_list"
        case table
        case image
        case pageBreak = "page_break"
        case horizontalRule = "horizontal_rule"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ElementType.self, forKey: .type)

        switch type {
        case .heading:
            let level = try container.decode(Int.self, forKey: .level)
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .heading(level: level, text: text, style: style)

        case .paragraph:
            let runs = try container.decode([DocxRun].self, forKey: .runs)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            let alignment = try container.decodeIfPresent(ParagraphAlignment.self, forKey: .alignment)
            self = .paragraph(runs: runs, style: style, alignment: alignment)

        case .bulletList:
            let items = try container.decode([String].self, forKey: .items)
            self = .bulletList(items: items)

        case .numberedList:
            let items = try container.decode([String].self, forKey: .items)
            self = .numberedList(items: items)

        case .table:
            let headers = try container.decodeIfPresent([String].self, forKey: .headers)
            let rows = try container.decode([[String]].self, forKey: .rows)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            let columnWidths = try container.decodeIfPresent([Int].self, forKey: .columnWidths)
            self = .table(DocxTable(headers: headers, rows: rows, style: style, columnWidths: columnWidths))

        case .image:
            let path = try container.decode(String.self, forKey: .path)
            let width = try container.decodeIfPresent(Int.self, forKey: .width)
            let height = try container.decodeIfPresent(Int.self, forKey: .height)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(DocxImage(path: path, width: width, height: height, caption: caption))

        case .pageBreak:
            self = .pageBreak

        case .horizontalRule:
            self = .horizontalRule
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .heading(level, text, style):
            try container.encode(ElementType.heading, forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(style, forKey: .style)

        case let .paragraph(runs, style, alignment):
            try container.encode(ElementType.paragraph, forKey: .type)
            try container.encode(runs, forKey: .runs)
            try container.encodeIfPresent(style, forKey: .style)
            try container.encodeIfPresent(alignment, forKey: .alignment)

        case let .bulletList(items):
            try container.encode(ElementType.bulletList, forKey: .type)
            try container.encode(items, forKey: .items)

        case let .numberedList(items):
            try container.encode(ElementType.numberedList, forKey: .type)
            try container.encode(items, forKey: .items)

        case let .table(docxTable):
            try container.encode(ElementType.table, forKey: .type)
            try container.encodeIfPresent(docxTable.headers, forKey: .headers)
            try container.encode(docxTable.rows, forKey: .rows)
            try container.encodeIfPresent(docxTable.style, forKey: .style)
            try container.encodeIfPresent(docxTable.columnWidths, forKey: .columnWidths)

        case let .image(docxImage):
            try container.encode(ElementType.image, forKey: .type)
            try container.encode(docxImage.path, forKey: .path)
            try container.encodeIfPresent(docxImage.width, forKey: .width)
            try container.encodeIfPresent(docxImage.height, forKey: .height)
            try container.encodeIfPresent(docxImage.caption, forKey: .caption)

        case .pageBreak:
            try container.encode(ElementType.pageBreak, forKey: .type)

        case .horizontalRule:
            try container.encode(ElementType.horizontalRule, forKey: .type)
        }
    }
}

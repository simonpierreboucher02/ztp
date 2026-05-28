// DocxDocument.swift
// ZTPDocx – Top-level document model

import Foundation

public struct DocxDocument: Sendable {
    public let title: String?
    public let author: String?
    public let sections: [DocxSection]

    public init(
        title: String? = nil,
        author: String? = nil,
        sections: [DocxSection]
    ) {
        self.title = title
        self.author = author
        self.sections = sections
    }

    /// Count of heading and paragraph elements across all sections.
    public var totalParagraphs: Int {
        sections.flatMap(\.elements).reduce(0) { count, element in
            switch element {
            case .heading, .paragraph:
                return count + 1
            default:
                return count
            }
        }
    }

    /// Count of table elements across all sections.
    public var totalTables: Int {
        sections.flatMap(\.elements).reduce(0) { count, element in
            if case .table = element { return count + 1 }
            return count
        }
    }

    /// Count of image elements across all sections.
    public var totalImages: Int {
        sections.flatMap(\.elements).reduce(0) { count, element in
            if case .image = element { return count + 1 }
            return count
        }
    }

    /// Count of heading elements across all sections.
    public var totalHeadings: Int {
        sections.flatMap(\.elements).reduce(0) { count, element in
            if case .heading = element { return count + 1 }
            return count
        }
    }
}

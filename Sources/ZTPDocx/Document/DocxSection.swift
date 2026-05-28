// DocxSection.swift
// ZTPDocx – A document section with optional header/footer

import Foundation

public struct DocxSection: Codable, Sendable, Equatable {
    public let elements: [DocxElement]
    public let header: String?
    public let footer: String?

    public init(
        elements: [DocxElement],
        header: String? = nil,
        footer: String? = nil
    ) {
        self.elements = elements
        self.header = header
        self.footer = footer
    }
}

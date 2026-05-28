// DocxImage.swift
// ZTPDocx – Image reference data model

import Foundation

public struct DocxImage: Codable, Sendable, Equatable {
    public let path: String
    public let width: Int?   // in points
    public let height: Int?  // in points
    public let caption: String?

    public init(
        path: String,
        width: Int? = nil,
        height: Int? = nil,
        caption: String? = nil
    ) {
        self.path = path
        self.width = width
        self.height = height
        self.caption = caption
    }
}

import Foundation

public struct PageMetadata: Codable, Sendable {
    public let title: String?
    public let description: String?
    public let canonicalURL: String?
    public let ogTitle: String?
    public let ogDescription: String?
    public let ogImage: String?
    public let headings: [HeadingInfo]
    public let linkCount: Int
    public let textLength: Int

    public init(
        title: String?,
        description: String?,
        canonicalURL: String?,
        ogTitle: String?,
        ogDescription: String?,
        ogImage: String?,
        headings: [HeadingInfo],
        linkCount: Int,
        textLength: Int
    ) {
        self.title = title
        self.description = description
        self.canonicalURL = canonicalURL
        self.ogTitle = ogTitle
        self.ogDescription = ogDescription
        self.ogImage = ogImage
        self.headings = headings
        self.linkCount = linkCount
        self.textLength = textLength
    }
}

public struct HeadingInfo: Codable, Sendable {
    public let level: Int
    public let text: String

    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

public struct LinkInfo: Codable, Sendable {
    public let text: String
    public let href: String
    public let isExternal: Bool

    public init(text: String, href: String, isExternal: Bool) {
        self.text = text
        self.href = href
        self.isExternal = isExternal
    }
}

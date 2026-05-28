import Foundation

/// Describes how an image is fitted within its bounding box.
public enum ImageFit: String, Codable, Sendable, Equatable {
    case contain
    case cover
    case stretch
}

/// An image element that can be placed on a slide.
public struct PptxImage: Codable, Sendable, Equatable {
    /// File path or URL of the image.
    public let path: String
    /// Width in EMU (optional).
    public let width: Int?
    /// Height in EMU (optional).
    public let height: Int?
    /// How the image should be fitted.
    public let fit: ImageFit?
    /// Optional caption text.
    public let caption: String?

    public init(
        path: String,
        width: Int? = nil,
        height: Int? = nil,
        fit: ImageFit? = nil,
        caption: String? = nil
    ) {
        self.path = path
        self.width = width
        self.height = height
        self.fit = fit
        self.caption = caption
    }
}

import Foundation

/// The geometric type of a shape.
public enum ShapeType: String, Codable, Sendable, Equatable {
    case rectangle = "rect"
    case roundedRectangle = "roundRect"
    case ellipse
    case line
    case divider
    case callout
}

/// A shape element that can be placed on a slide.
public struct PptxShape: Codable, Sendable, Equatable {
    /// The geometric shape type.
    public let type: ShapeType
    /// Optional text inside the shape.
    public let text: String?
    /// Fill color as a hex string (no "#" prefix).
    public let fillColor: String?
    /// Border color as a hex string (no "#" prefix).
    public let borderColor: String?
    /// Width in EMU (optional).
    public let width: Int?
    /// Height in EMU (optional).
    public let height: Int?

    public init(
        type: ShapeType,
        text: String? = nil,
        fillColor: String? = nil,
        borderColor: String? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.type = type
        self.text = text
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.width = width
        self.height = height
    }
}

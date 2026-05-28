import Foundation

/// Slide layout presets controlling how content is arranged on a slide.
public enum PptxLayout: String, Codable, Sendable, Equatable {
    case title
    case titleContent = "title-content"
    case twoColumn = "two-column"
    case imageRight = "image-right"
    case imageLeft = "image-left"
    case table
    case sectionDivider = "section-divider"
    case quote
    case blank
}

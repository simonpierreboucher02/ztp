import Foundation

/// A single slide in a presentation.
public struct PptxSlide: Sendable, Equatable {
    /// The layout preset for this slide.
    public let layout: PptxLayout
    /// Optional slide title.
    public let title: String?
    /// Optional slide subtitle.
    public let subtitle: String?
    /// Content elements on this slide.
    public let content: [PptxElement]
    /// Optional speaker notes.
    public let notes: String?

    public init(
        layout: PptxLayout = .blank,
        title: String? = nil,
        subtitle: String? = nil,
        content: [PptxElement] = [],
        notes: String? = nil
    ) {
        self.layout = layout
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.notes = notes
    }
}

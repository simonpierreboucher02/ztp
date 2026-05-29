import Foundation

/// A complete PowerPoint presentation model.
public struct PptxPresentation: Sendable {
    /// Optional presentation title.
    public let title: String?
    /// Optional author name.
    public let author: String?
    /// Slide dimensions.
    public let size: SlideSize
    /// Visual theme.
    public let theme: PptxTheme
    /// The ordered list of slides.
    public let slides: [PptxSlide]
    /// Whether to render a slide-number badge on each slide.
    public let showSlideNumbers: Bool

    public init(
        title: String? = nil,
        author: String? = nil,
        size: SlideSize = .widescreen,
        theme: PptxTheme = .defaultTheme,
        slides: [PptxSlide],
        showSlideNumbers: Bool = false
    ) {
        self.title = title
        self.author = author
        self.size = size
        self.theme = theme
        self.slides = slides
        self.showSlideNumbers = showSlideNumbers
    }

    /// Total number of slides.
    public var totalSlides: Int {
        slides.count
    }

    /// Total number of image elements across all slides.
    public var totalImages: Int {
        slides.reduce(0) { count, slide in
            count + slide.content.filter { element in
                if case .image = element { return true }
                return false
            }.count
        }
    }

    /// Total number of table elements across all slides.
    public var totalTables: Int {
        slides.reduce(0) { count, slide in
            count + slide.content.filter { element in
                if case .table = element { return true }
                return false
            }.count
        }
    }
}

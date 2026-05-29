import Testing
import Foundation
@testable import ZTPSlides

@Suite("Slide Number Tests")
struct SlideNumberTests {

    @Test("Slide number badge renders the 1-based number")
    func badgeRenders() {
        let slide = PptxSlide(layout: .title, title: "Hello")
        let xml = SlideWriter.toXML(
            slide: slide,
            slideIndex: 4,
            theme: .defaultTheme,
            size: .widescreen,
            imageRelationships: [:],
            showSlideNumber: true
        )
        #expect(xml.contains("name=\"SlideNumber\""))
        #expect(xml.contains("<a:t>5</a:t>"))
    }

    @Test("No badge when disabled")
    func noBadge() {
        let slide = PptxSlide(layout: .title, title: "Hello")
        let xml = SlideWriter.toXML(
            slide: slide,
            slideIndex: 0,
            theme: .defaultTheme,
            size: .widescreen,
            imageRelationships: [:],
            showSlideNumber: false
        )
        #expect(!xml.contains("name=\"SlideNumber\""))
    }

    @Test("Spec slideNumbers flag flows into the model")
    func specFlag() throws {
        let json = """
        {"version":"ztp-slides/0.1","presentation":{"title":"d","slideNumbers":true},"slides":[{"layout":"title","title":"a"}]}
        """
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: Data(json.utf8))
        let model = try spec.toPresentation()
        #expect(model.showSlideNumbers)
    }
}

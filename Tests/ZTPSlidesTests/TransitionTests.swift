import Testing
import Foundation
@testable import ZTPSlides

@Suite("Slide Transition Tests")
struct TransitionTests {

    @Test("Transition renders a <p:transition> element")
    func renders() {
        let slide = PptxSlide(layout: .title, title: "A", transition: "push")
        let xml = SlideWriter.toXML(
            slide: slide, slideIndex: 0, theme: .defaultTheme,
            size: .widescreen, imageRelationships: [:]
        )
        #expect(xml.contains("<p:transition"))
        #expect(xml.contains("<p:push/>"))
    }

    @Test("Unknown transition falls back to fade")
    func fallback() {
        let slide = PptxSlide(layout: .title, title: "A", transition: "bogus")
        let xml = SlideWriter.toXML(
            slide: slide, slideIndex: 0, theme: .defaultTheme,
            size: .widescreen, imageRelationships: [:]
        )
        #expect(xml.contains("<p:fade/>"))
    }

    @Test("No transition emits nothing")
    func none() {
        let slide = PptxSlide(layout: .title, title: "A")
        let xml = SlideWriter.toXML(
            slide: slide, slideIndex: 0, theme: .defaultTheme,
            size: .widescreen, imageRelationships: [:]
        )
        #expect(!xml.contains("<p:transition"))
    }
}

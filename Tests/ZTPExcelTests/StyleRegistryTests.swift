import Testing
import Foundation
@testable import ZTPExcel

@Suite("StyleRegistry Tests")
struct StyleRegistryTests {

    @Test("Register and resolve style")
    func registerAndResolve() {
        var registry = StyleRegistry()
        let style = CellStyle(font: FontStyle(bold: true))
        let id = registry.register(name: "bold", style: style)

        let resolved = registry.resolve(name: "bold")
        #expect(resolved?.id == id)
        #expect(resolved?.style == style)
    }

    @Test("Deduplicates identical styles")
    func deduplication() {
        var registry = StyleRegistry()
        let style = CellStyle(font: FontStyle(bold: true))

        let id1 = registry.register(name: "bold1", style: style)
        let id2 = registry.register(name: "bold2", style: style)

        #expect(id1 == id2)
        #expect(registry.allStyles.count == 1)
    }

    @Test("Different styles get different IDs")
    func differentStyles() {
        var registry = StyleRegistry()
        let id1 = registry.register(name: "bold", style: CellStyle(font: FontStyle(bold: true)))
        let id2 = registry.register(name: "italic", style: CellStyle(font: FontStyle(italic: true)))

        #expect(id1 != id2)
        #expect(registry.allStyles.count == 2)
    }

    @Test("Unknown style returns nil")
    func unknownStyle() {
        let registry = StyleRegistry()
        #expect(registry.resolve(name: "nonexistent") == nil)
    }
}

import Testing
import Foundation
@testable import ZTPFinder

@Suite("ZTPFinder Tests")
struct ZTPFinderTests {
    @Test("Manifest name + capabilities")
    func manifest() {
        let tool = ZTPFinderTool()
        #expect(tool.manifest.name == "ztp-finder")
        #expect(tool.manifest.capabilities.contains("selection"))
        #expect(tool.manifest.capabilities.contains("set-view"))
        #expect(tool.manifest.permissions["applescript"] == true)
    }

    @Test("Invalid view rejected")
    func invalidView() {
        #expect(throws: (any Error).self) {
            _ = try FinderControl.setView("hologram", path: nil)
        }
    }

    @Test("Trash requires confirmation")
    func trashConfirm() {
        #expect(throws: (any Error).self) {
            _ = try FinderControl.trash(path: NSHomeDirectory(), confirmed: false)
        }
    }

    @Test("Empty trash requires confirmation")
    func emptyTrashConfirm() {
        #expect(throws: (any Error).self) {
            _ = try FinderControl.emptyTrash(confirmed: false)
        }
    }

    @Test("Reveal missing path throws")
    func revealMissing() {
        #expect(throws: (any Error).self) {
            _ = try FinderControl.reveal(path: "/nonexistent_\(UUID().uuidString)")
        }
    }
}

import Testing
import Foundation
@testable import ZTPMacOS
@testable import ZTPProtocols

@Suite("ZTPMacOS Tool Tests")
struct ZTPMacOSToolTests {
    @Test("Manifest has correct name")
    func manifestName() {
        let tool = ZTPMacOSTool()
        #expect(tool.manifest.name == "ztp-macos")
        #expect(tool.manifest.version == "0.1.0")
    }

    @Test("Manifest capabilities")
    func capabilities() {
        let tool = ZTPMacOSTool()
        #expect(tool.manifest.capabilities.contains("system.info"))
        #expect(tool.manifest.capabilities.contains("clipboard.get"))
        #expect(tool.manifest.capabilities.contains("screenshot.full"))
        #expect(tool.manifest.capabilities.contains("applescript.run"))
        #expect(tool.manifest.capabilities.contains("shortcuts.list"))
        #expect(tool.manifest.capabilities.contains("finder.reveal"))
    }

    @Test("File exists helper")
    func fileExists() {
        #expect(FileOperations.exists(path: NSHomeDirectory()))
        #expect(!FileOperations.exists(path: "/nonexistent_path_\(UUID().uuidString)"))
    }

    @Test("Write requires confirmation")
    func writeConfirm() {
        #expect(throws: (any Error).self) {
            _ = try FileOperations.write(path: "/tmp/test", content: "x", confirmed: false)
        }
    }

    @Test("Move requires confirmation")
    func moveConfirm() {
        #expect(throws: (any Error).self) {
            _ = try FileOperations.move(from: "/tmp/a", to: "/tmp/b", confirmed: false)
        }
    }

    @Test("Delete requires confirmation")
    func deleteConfirm() {
        #expect(throws: (any Error).self) {
            _ = try FileOperations.delete(path: "/tmp/x", confirmed: false)
        }
    }

    @Test("AppleScript run requires confirmation")
    func asConfirm() {
        #expect(throws: (any Error).self) {
            _ = try AppleScriptEngine.run(script: "return 1", confirmed: false)
        }
    }

    @Test("AppleScript validate")
    func asValidate() {
        #expect(AppleScriptEngine.validate(script: "return 1"))
        #expect(!AppleScriptEngine.validate(script: ""))
    }

    @Test("Shortcuts run requires confirmation")
    func shortcutsConfirm() {
        #expect(throws: (any Error).self) {
            _ = try ShortcutsBridge.run(name: "Test", confirmed: false)
        }
    }

    @Test("App quit requires confirmation")
    func quitConfirm() {
        #expect(throws: (any Error).self) {
            _ = try AppLauncher.quit(appName: "Test", confirmed: false)
        }
    }
}

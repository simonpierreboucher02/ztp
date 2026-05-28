import Testing
import Foundation
@testable import ZTPProtocols

@Suite("ToolManifest Tests")
struct ToolManifestTests {

    @Test("Create manifest with defaults")
    func createWithDefaults() {
        let manifest = ToolManifest(name: "ztp-test", version: "1.0.0")
        #expect(manifest.name == "ztp-test")
        #expect(manifest.version == "1.0.0")
        #expect(manifest.protocolVersion == "ztp/1")
        #expect(manifest.capabilities.isEmpty)
        #expect(manifest.permissions.isEmpty)
    }

    @Test("Create manifest with all fields")
    func createWithAllFields() {
        let manifest = ToolManifest(
            name: "ztp-full",
            version: "2.0.0",
            protocolVersion: "ztp/2",
            capabilities: ["read", "write"],
            permissions: ["filesystem": true, "network": false]
        )
        #expect(manifest.name == "ztp-full")
        #expect(manifest.capabilities.count == 2)
        #expect(manifest.permissions["filesystem"] == true)
        #expect(manifest.permissions["network"] == false)
    }

    @Test("JSON round-trip encoding")
    func jsonRoundTrip() throws {
        let manifest = ToolManifest(
            name: "ztp-json",
            version: "1.0.0",
            capabilities: ["compute"]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(manifest)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolManifest.self, from: data)
        #expect(decoded == manifest)
    }

    @Test("Decode from JSON with protocol key")
    func decodeFromJSON() throws {
        let json = """
        {
            "name": "ztp-example",
            "version": "1.0.0",
            "protocol": "ztp/1",
            "capabilities": [],
            "permissions": {}
        }
        """
        let data = Data(json.utf8)
        let manifest = try JSONDecoder().decode(ToolManifest.self, from: data)
        #expect(manifest.name == "ztp-example")
        #expect(manifest.protocolVersion == "ztp/1")
    }
}

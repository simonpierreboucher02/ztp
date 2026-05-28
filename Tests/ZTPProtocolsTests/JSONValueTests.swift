import Testing
import Foundation
@testable import ZTPProtocols

@Suite("JSONValue Tests")
struct JSONValueTests {

    @Test("Encode and decode string")
    func stringRoundTrip() throws {
        let value = JSONValue.string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Encode and decode int")
    func intRoundTrip() throws {
        let value = JSONValue.int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Encode and decode bool")
    func boolRoundTrip() throws {
        let value = JSONValue.bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Encode and decode null")
    func nullRoundTrip() throws {
        let value = JSONValue.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Encode and decode nested object")
    func nestedObject() throws {
        let value = JSONValue.object([
            "key": .string("value"),
            "count": .int(3),
            "items": .array([.string("a"), .string("b")]),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("ToolInput accessors")
    func toolInputAccessors() {
        let input = ToolInput(parameters: [
            "name": .string("test"),
            "count": .int(5),
            "verbose": .bool(true),
        ])
        #expect(input.string(for: "name") == "test")
        #expect(input.int(for: "count") == 5)
        #expect(input.bool(for: "verbose") == true)
        #expect(input.string(for: "missing") == nil)
    }
}

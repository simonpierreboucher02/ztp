import Foundation

public struct ToolInput: Sendable {
    public let parameters: [String: JSONValue]
    public let rawJSON: Data?

    public init(parameters: [String: JSONValue] = [:], rawJSON: Data? = nil) {
        self.parameters = parameters
        self.rawJSON = rawJSON
    }

    public func string(for key: String) -> String? {
        if case .string(let value) = parameters[key] {
            return value
        }
        return nil
    }

    public func int(for key: String) -> Int? {
        if case .int(let value) = parameters[key] {
            return value
        }
        return nil
    }

    public func bool(for key: String) -> Bool? {
        if case .bool(let value) = parameters[key] {
            return value
        }
        return nil
    }
}

import Foundation

public struct ToolManifest: Codable, Sendable, Equatable {
    public let name: String
    public let version: String
    public let protocolVersion: String
    public let capabilities: [String]
    public let permissions: [String: Bool]

    public init(
        name: String,
        version: String,
        protocolVersion: String = "ztp/1",
        capabilities: [String] = [],
        permissions: [String: Bool] = [:]
    ) {
        self.name = name
        self.version = version
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.permissions = permissions
    }

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case protocolVersion = "protocol"
        case capabilities
        case permissions
    }
}

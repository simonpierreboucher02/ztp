import Foundation

public enum MessageBodyType: String, Codable, Sendable, Equatable {
    case plain
}

public struct MessageBody: Codable, Sendable, Equatable {
    public let type: MessageBodyType
    public let content: String

    public init(type: MessageBodyType = .plain, content: String) {
        self.type = type
        self.content = content
    }

    public var characterCount: Int {
        content.count
    }
}

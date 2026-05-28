import Foundation

public enum MailBodyType: String, Codable, Sendable, Equatable {
    case plain
    case html
    case markdown
}

public struct MailBody: Codable, Sendable, Equatable {
    public let type: MailBodyType
    public let content: String

    public init(type: MailBodyType = .plain, content: String) {
        self.type = type
        self.content = content
    }
}

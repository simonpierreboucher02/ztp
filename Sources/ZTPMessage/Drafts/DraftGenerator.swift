import Foundation

public struct DraftGenerator: Sendable {

    // MARK: - Output Types

    public struct DraftOutput: Codable, Sendable {
        public let version: String
        public let channel: String
        public let recipients: [DraftRecipient]
        public let body: String
        public let characterCount: Int
        public let createdAt: String

        public init(
            version: String,
            channel: String,
            recipients: [DraftRecipient],
            body: String,
            characterCount: Int,
            createdAt: String
        ) {
            self.version = version
            self.channel = channel
            self.recipients = recipients
            self.body = body
            self.characterCount = characterCount
            self.createdAt = createdAt
        }

        enum CodingKeys: String, CodingKey {
            case version
            case channel
            case recipients
            case body
            case characterCount = "character_count"
            case createdAt = "created_at"
        }
    }

    public struct DraftRecipient: Codable, Sendable {
        public let name: String?
        public let address: String

        public init(name: String? = nil, address: String) {
            self.name = name
            self.address = address
        }
    }

    // MARK: - Generation

    public static func generate(message: ShortMessage) -> DraftOutput {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = formatter.string(from: Date())

        let recipients = message.to.map { recipient in
            DraftRecipient(name: recipient.name, address: recipient.address)
        }

        return DraftOutput(
            version: "ztp-message/0.1",
            channel: message.channel.rawValue,
            recipients: recipients,
            body: message.body.content,
            characterCount: message.characterCount,
            createdAt: now
        )
    }

    public static func generateJSON(message: ShortMessage) throws -> Data {
        let draft = generate(message: message)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(draft)
    }
}

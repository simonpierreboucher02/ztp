import Foundation

public struct DraftInspector: Sendable {

    // MARK: - DraftInfo

    public struct DraftInfo: Codable, Sendable {
        public let channel: String?
        public let recipients: [String]
        public let body: String?
        public let characterCount: Int
        public let createdAt: String?

        public init(
            channel: String? = nil,
            recipients: [String] = [],
            body: String? = nil,
            characterCount: Int = 0,
            createdAt: String? = nil
        ) {
            self.channel = channel
            self.recipients = recipients
            self.body = body
            self.characterCount = characterCount
            self.createdAt = createdAt
        }

        enum CodingKeys: String, CodingKey {
            case channel
            case recipients
            case body
            case characterCount = "character_count"
            case createdAt = "created_at"
        }
    }

    // MARK: - Inspect from file path

    public static func inspect(at path: String) throws -> DraftInfo {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try inspect(data: data)
    }

    // MARK: - Inspect from data

    public static func inspect(data: Data) throws -> DraftInfo {
        let decoder = JSONDecoder()
        let draft = try decoder.decode(DraftGenerator.DraftOutput.self, from: data)

        let recipientAddresses = draft.recipients.map { recipient in
            if let name = recipient.name {
                return "\(name) <\(recipient.address)>"
            }
            return recipient.address
        }

        return DraftInfo(
            channel: draft.channel,
            recipients: recipientAddresses,
            body: draft.body,
            characterCount: draft.characterCount,
            createdAt: draft.createdAt
        )
    }
}

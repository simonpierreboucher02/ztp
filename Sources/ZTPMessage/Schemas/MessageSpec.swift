import Foundation

// MARK: - Errors

public enum MessageSpecError: Error, Sendable {
    case invalidChannel(String)
    case noRecipients
    case emptyBody
    case unsupportedVersion(String)
}

// MARK: - RecipientSpec

public struct RecipientSpec: Sendable, Equatable {
    public let name: String?
    public let address: String

    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }
}

extension RecipientSpec: Codable {
    public init(from decoder: Decoder) throws {
        // Accept either a plain string (address only) or an object { name?, address }
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            self.name = nil
            self.address = stringValue
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.address = try container.decode(String.self, forKey: .address)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(address, forKey: .address)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case address
    }
}

// MARK: - BodySpec

public struct BodySpec: Codable, Sendable {
    public let type: String?
    public let content: String

    public init(type: String? = nil, content: String) {
        self.type = type
        self.content = content
    }
}

// MARK: - MessageContentSpec

public struct MessageContentSpec: Codable, Sendable {
    public let channel: String?
    public let to: [RecipientSpec]
    public let body: BodySpec
    public let template: String?
    public let variables: [String: String]?

    public init(
        channel: String? = nil,
        to: [RecipientSpec],
        body: BodySpec,
        template: String? = nil,
        variables: [String: String]? = nil
    ) {
        self.channel = channel
        self.to = to
        self.body = body
        self.template = template
        self.variables = variables
    }
}

// MARK: - MessageSpec

public struct MessageSpec: Codable, Sendable {
    public let version: String
    public let message: MessageContentSpec

    public init(version: String = "ztp-message/0.1", message: MessageContentSpec) {
        self.version = version
        self.message = message
    }

    public func toMessage() throws -> ShortMessage {
        // Validate version
        guard version == "ztp-message/0.1" else {
            throw MessageSpecError.unsupportedVersion(version)
        }

        // Validate recipients
        guard !message.to.isEmpty else {
            throw MessageSpecError.noRecipients
        }

        // Resolve body content: use template if specified, otherwise raw body content
        let resolvedContent: String
        if let templateName = message.template,
           let tmpl = MessageTemplateEngine.get(named: templateName) {
            resolvedContent = try MessageTemplateEngine.render(
                template: tmpl.pattern,
                variables: message.variables ?? [:]
            )
        } else {
            resolvedContent = message.body.content
        }

        // Validate body
        guard !resolvedContent.isEmpty else {
            throw MessageSpecError.emptyBody
        }

        // Parse channel
        let channel: MessageChannel
        if let channelStr = message.channel {
            guard let parsed = MessageChannel(rawValue: channelStr) else {
                throw MessageSpecError.invalidChannel(channelStr)
            }
            channel = parsed
        } else {
            channel = .imessage
        }

        // Build recipients
        let recipients = message.to.map { spec in
            MessageRecipient(name: spec.name, address: spec.address)
        }

        let bodyType: MessageBodyType
        if let typeStr = message.body.type {
            bodyType = MessageBodyType(rawValue: typeStr) ?? .plain
        } else {
            bodyType = .plain
        }

        let body = MessageBody(type: bodyType, content: resolvedContent)

        return ShortMessage(channel: channel, to: recipients, body: body)
    }
}

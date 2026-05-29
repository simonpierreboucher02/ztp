import Foundation

// MARK: - Errors

public enum MailSpecError: Error, Sendable {
    case invalidVersion(String)
    case missingRecipients
    case invalidRecipientEmail(String)
    case missingSubject
    case missingBody
    case decodingFailed(String)
}

// MARK: - RecipientSpec (flexible: string or object)

public struct RecipientSpec: Codable, Sendable, Equatable {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        // Try decoding as a plain string first
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            self.email = stringValue
            self.name = nil
            return
        }
        // Otherwise decode as an object with email + optional name
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.email = try container.decode(String.self, forKey: .email)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
    }

    public func encode(to encoder: Encoder) throws {
        if name == nil {
            var container = encoder.singleValueContainer()
            try container.encode(email)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(email, forKey: .email)
            try container.encodeIfPresent(name, forKey: .name)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case email
        case name
    }

    public func toMailAddress() -> MailAddress {
        MailAddress(email: email, name: name)
    }
}

// MARK: - BodySpec

public struct BodySpec: Codable, Sendable, Equatable {
    public let type: MailBodyType
    public let content: String

    public init(type: MailBodyType, content: String) {
        self.type = type
        self.content = content
    }

    public func toMailBody() -> MailBody {
        MailBody(type: type, content: content)
    }
}

// MARK: - AttachmentSpec

public struct AttachmentSpec: Codable, Sendable, Equatable {
    public let path: String
    public let name: String?
    public let mimeType: String?

    public init(path: String, name: String? = nil, mimeType: String? = nil) {
        self.path = path
        self.name = name
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case path
        case name
        case mimeType = "mime_type"
    }

    public func toMailAttachment() -> MailAttachment {
        MailAttachment(path: path, name: name, mimeType: mimeType)
    }
}

// MARK: - InlineImageSpec

/// An image embedded in the HTML body, referenced as `cid:<cid>`.
public struct InlineImageSpec: Codable, Sendable, Equatable {
    public let path: String
    public let cid: String
    public let mimeType: String?

    private enum CodingKeys: String, CodingKey {
        case path, cid
        case mimeType = "mime_type"
    }

    public func toInlineImage() -> MailInlineImage {
        MailInlineImage(path: path, cid: cid, mimeType: mimeType)
    }
}

// MARK: - MessageSpec

public struct MessageSpec: Codable, Sendable, Equatable {
    public let from: RecipientSpec?
    public let to: [RecipientSpec]
    public let cc: [RecipientSpec]?
    public let bcc: [RecipientSpec]?
    public let replyTo: RecipientSpec?
    public let subject: String
    public let body: BodySpec
    public let attachments: [AttachmentSpec]?
    public let signature: String?
    /// Priority: "high", "normal", or "low".
    public let priority: String?
    /// Arbitrary additional headers.
    public let headers: [String: String]?
    /// Inline images embedded in the HTML body.
    public let inlineImages: [InlineImageSpec]?

    public init(
        from: RecipientSpec? = nil,
        to: [RecipientSpec],
        cc: [RecipientSpec]? = nil,
        bcc: [RecipientSpec]? = nil,
        replyTo: RecipientSpec? = nil,
        subject: String,
        body: BodySpec,
        attachments: [AttachmentSpec]? = nil,
        signature: String? = nil,
        priority: String? = nil,
        headers: [String: String]? = nil,
        inlineImages: [InlineImageSpec]? = nil
    ) {
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.replyTo = replyTo
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.signature = signature
        self.priority = priority
        self.headers = headers
        self.inlineImages = inlineImages
    }

    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case cc
        case bcc
        case replyTo = "reply_to"
        case subject
        case body
        case attachments
        case signature
        case priority
        case headers
        case inlineImages = "inline_images"
    }
}

// MARK: - MailSpec (top-level)

public struct MailSpec: Codable, Sendable, Equatable {
    public let version: String
    public let message: MessageSpec

    public init(version: String, message: MessageSpec) {
        self.version = version
        self.message = message
    }

    /// Decode a `MailSpec` from JSON data.
    public static func decode(from data: Data) throws -> MailSpec {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(MailSpec.self, from: data)
        } catch {
            throw MailSpecError.decodingFailed(error.localizedDescription)
        }
    }

    /// Convert the spec into a validated `MailMessage`.
    public func toMessage() throws -> MailMessage {
        // Validate version
        guard version.hasPrefix("ztp-mail/") else {
            throw MailSpecError.invalidVersion(version)
        }

        // Validate recipients
        guard !message.to.isEmpty else {
            throw MailSpecError.missingRecipients
        }

        // Validate subject
        guard !message.subject.isEmpty else {
            throw MailSpecError.missingSubject
        }

        // Validate body
        guard !message.body.content.isEmpty else {
            throw MailSpecError.missingBody
        }

        // Convert recipients, validating emails
        let toAddresses = try message.to.map { spec -> MailAddress in
            let addr = spec.toMailAddress()
            guard addr.isValid else {
                throw MailSpecError.invalidRecipientEmail(spec.email)
            }
            return addr
        }

        let ccAddresses = try (message.cc ?? []).map { spec -> MailAddress in
            let addr = spec.toMailAddress()
            guard addr.isValid else {
                throw MailSpecError.invalidRecipientEmail(spec.email)
            }
            return addr
        }

        let bccAddresses = try (message.bcc ?? []).map { spec -> MailAddress in
            let addr = spec.toMailAddress()
            guard addr.isValid else {
                throw MailSpecError.invalidRecipientEmail(spec.email)
            }
            return addr
        }

        let fromAddress: MailAddress?
        if let fromSpec = message.from {
            let addr = fromSpec.toMailAddress()
            guard addr.isValid else {
                throw MailSpecError.invalidRecipientEmail(fromSpec.email)
            }
            fromAddress = addr
        } else {
            fromAddress = nil
        }

        let replyToAddress: MailAddress?
        if let replySpec = message.replyTo {
            let addr = replySpec.toMailAddress()
            guard addr.isValid else {
                throw MailSpecError.invalidRecipientEmail(replySpec.email)
            }
            replyToAddress = addr
        } else {
            replyToAddress = nil
        }

        let attachments = (message.attachments ?? []).map { $0.toMailAttachment() }

        return MailMessage(
            from: fromAddress,
            to: toAddresses,
            cc: ccAddresses,
            bcc: bccAddresses,
            subject: message.subject,
            body: message.body.toMailBody(),
            attachments: attachments,
            replyTo: replyToAddress,
            signature: message.signature,
            priority: message.priority,
            customHeaders: message.headers ?? [:],
            inlineImages: (message.inlineImages ?? []).map { $0.toInlineImage() }
        )
    }
}

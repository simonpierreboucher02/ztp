import Foundation

/// An image embedded in the HTML body via `<img src="cid:CID">`, carried as a
/// `multipart/related` part with a matching Content-ID.
public struct MailInlineImage: Sendable {
    public let path: String
    public let cid: String
    public let mimeType: String?
    public init(path: String, cid: String, mimeType: String? = nil) {
        self.path = path; self.cid = cid; self.mimeType = mimeType
    }
}

public struct MailMessage: Sendable {
    public let from: MailAddress?
    public let to: [MailAddress]
    public let cc: [MailAddress]
    public let bcc: [MailAddress]
    public let subject: String
    public let body: MailBody
    public let attachments: [MailAttachment]
    public let replyTo: MailAddress?
    public let signature: String?
    /// Priority: "high", "normal", or "low" (emits X-Priority/Importance).
    public let priority: String?
    /// Arbitrary extra headers (e.g. "X-Campaign": "spring").
    public let customHeaders: [String: String]
    /// Images embedded in the HTML body (referenced as cid:CID).
    public let inlineImages: [MailInlineImage]

    public init(
        from: MailAddress? = nil,
        to: [MailAddress],
        cc: [MailAddress] = [],
        bcc: [MailAddress] = [],
        subject: String,
        body: MailBody,
        attachments: [MailAttachment] = [],
        replyTo: MailAddress? = nil,
        signature: String? = nil,
        priority: String? = nil,
        customHeaders: [String: String] = [:],
        inlineImages: [MailInlineImage] = []
    ) {
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.replyTo = replyTo
        self.signature = signature
        self.priority = priority
        self.customHeaders = customHeaders
        self.inlineImages = inlineImages
    }

    /// Total number of recipients across to, cc, and bcc.
    public var recipientCount: Int {
        to.count + cc.count + bcc.count
    }

    /// Whether the message has any attachments.
    public var hasAttachments: Bool {
        !attachments.isEmpty
    }

    /// Character count of the body content.
    public var bodyCharCount: Int {
        body.content.count
    }
}

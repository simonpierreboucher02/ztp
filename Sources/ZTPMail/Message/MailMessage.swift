import Foundation

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

    public init(
        from: MailAddress? = nil,
        to: [MailAddress],
        cc: [MailAddress] = [],
        bcc: [MailAddress] = [],
        subject: String,
        body: MailBody,
        attachments: [MailAttachment] = [],
        replyTo: MailAddress? = nil,
        signature: String? = nil
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

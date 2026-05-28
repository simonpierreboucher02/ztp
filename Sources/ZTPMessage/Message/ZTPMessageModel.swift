import Foundation

public struct ShortMessage: Sendable, Equatable {
    public let channel: MessageChannel
    public let to: [MessageRecipient]
    public let body: MessageBody

    public init(channel: MessageChannel = .imessage, to: [MessageRecipient], body: MessageBody) {
        self.channel = channel
        self.to = to
        self.body = body
    }

    public var recipientCount: Int {
        to.count
    }

    public var characterCount: Int {
        body.characterCount
    }
}

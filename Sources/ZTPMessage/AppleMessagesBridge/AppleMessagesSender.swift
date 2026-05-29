import Foundation

public struct AppleMessagesSender: Sendable {

    // MARK: - Error Types

    public enum SendError: Error, Sendable {
        case confirmationRequired
        case unsupportedChannel(String)
        case scriptExecutionFailed(String)
        case messagesAppNotAvailable
    }

    // MARK: - Result

    public struct SendResult: Sendable {
        public let success: Bool
        public let message: String
        public let channel: String
        public let recipientsSent: Int

        public init(success: Bool, message: String, channel: String, recipientsSent: Int) {
            self.success = success
            self.message = message
            self.channel = channel
            self.recipientsSent = recipientsSent
        }
    }

    // MARK: - Send

    public static func send(message: ShortMessage, confirmed: Bool) throws -> SendResult {
        guard confirmed else {
            throw SendError.confirmationRequired
        }

        let escapedBody = escapeAppleScript(message.body.content)
        var sentCount = 0

        for recipient in message.to {
            let escapedAddress = escapeAppleScript(recipient.address)

            let script: String
            switch message.channel {
            case .imessage:
                script = """
                tell application "Messages"
                    set targetService to 1st account whose service type = iMessage
                    set targetBuddy to participant "\(escapedAddress)" of targetService
                    send "\(escapedBody)" to targetBuddy
                end tell
                """
            case .sms:
                // Messages.app handles SMS via the same interface on Mac
                script = """
                tell application "Messages"
                    set targetService to 1st account whose service type = iMessage
                    set targetBuddy to participant "\(escapedAddress)" of targetService
                    send "\(escapedBody)" to targetBuddy
                end tell
                """
            }

            try executeAppleScript(script)
            sentCount += 1
        }

        return SendResult(
            success: true,
            message: "Sent to \(sentCount) recipient(s) via \(message.channel.rawValue)",
            channel: message.channel.rawValue,
            recipientsSent: sentCount
        )
    }

    // MARK: - Create Draft (open Messages to recipient)

    public static func createDraft(message: ShortMessage) throws -> SendResult {
        guard let firstRecipient = message.to.first else {
            return SendResult(
                success: false,
                message: "No recipients specified",
                channel: message.channel.rawValue,
                recipientsSent: 0
            )
        }

        // Use imessage:// URL scheme to open Messages.app to the conversation
        let address = firstRecipient.address
        let urlString: String
        if firstRecipient.isPhoneNumber {
            urlString = "imessage://\(address)"
        } else {
            urlString = "imessage://\(address)"
        }

        let openScript = """
        do shell script "open '\(escapeAppleScript(urlString))'"
        """

        try executeAppleScript(openScript)

        return SendResult(
            success: true,
            message: "Opened Messages.app for \(firstRecipient.displayName). Compose your message manually.",
            channel: message.channel.rawValue,
            recipientsSent: 0
        )
    }

    // MARK: - Helpers

    /// Escape a string for safe inclusion in AppleScript double-quoted strings.
    ///
    /// Escapes backslash, quote AND newline/carriage-return/tab. Omitting the
    /// newline escapes (the previous behavior) allowed a crafted recipient or
    /// body to break out of the quoted string and inject AppleScript commands.
    private static func escapeAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Execute an AppleScript string via /usr/bin/osascript.
    private static func executeAppleScript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SendError.scriptExecutionFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

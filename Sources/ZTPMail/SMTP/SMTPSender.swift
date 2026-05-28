import Foundation

public struct SMTPSender: Sendable {

    public enum SendError: Error, Sendable {
        case confirmationRequired
        case profileNotFound(String)
        case connectionFailed(String)
        case authenticationFailed(String)
        case sendFailed(String)
        case configNotFound
    }

    public struct SendResult: Sendable {
        public let success: Bool
        public let messageId: String?
        public let message: String

        public init(success: Bool, messageId: String?, message: String) {
            self.success = success
            self.messageId = messageId
            self.message = message
        }
    }

    /// Send a mail message via SMTP using the given profile.
    ///
    /// This V1 implementation generates an .eml file and uses `/usr/bin/curl`
    /// with SMTP protocol to deliver it.
    ///
    /// - Parameters:
    ///   - message: The mail message to send.
    ///   - profile: The SMTP profile with server credentials.
    ///   - confirmed: Must be `true` or `confirmationRequired` is thrown.
    ///   - basePath: Optional base path for resolving relative attachment paths.
    /// - Returns: A `SendResult` describing the outcome.
    public static func send(
        message: MailMessage,
        profile: SMTPProfile,
        confirmed: Bool,
        basePath: String?
    ) throws -> SendResult {
        // Require explicit confirmation before sending
        guard confirmed else {
            throw SendError.confirmationRequired
        }

        // Verify curl is available
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: "/usr/bin/curl") else {
            throw SendError.sendFailed(
                "curl not found at /usr/bin/curl. Use apple-draft to create a draft in Apple Mail instead."
            )
        }

        // Generate the .eml data
        let emlData: Data
        do {
            emlData = try EMLGenerator.generate(message: message, basePath: basePath)
        } catch {
            throw SendError.sendFailed("Failed to generate EML: \(error)")
        }

        // Write the .eml to a temporary file
        let tempDir = NSTemporaryDirectory()
        let emlPath = "\(tempDir)ztp-mail-\(UUID().uuidString).eml"
        guard fileManager.createFile(atPath: emlPath, contents: emlData) else {
            throw SendError.sendFailed("Failed to write temporary EML file")
        }
        defer {
            try? fileManager.removeItem(atPath: emlPath)
        }

        // Determine the sender address
        let fromAddress = message.from?.email
            ?? profile.fromAddress
            ?? profile.username

        // Collect all recipients
        var recipients: [String] = []
        recipients.append(contentsOf: message.to.map(\.email))
        recipients.append(contentsOf: message.cc.map(\.email))
        recipients.append(contentsOf: message.bcc.map(\.email))

        guard !recipients.isEmpty else {
            throw SendError.sendFailed("No recipients specified")
        }

        // Build curl arguments
        var arguments: [String] = []

        // URL with protocol and port
        let protocol_: String
        switch profile.encryption {
        case .ssl:
            protocol_ = "smtps"
        case .starttls, .none:
            protocol_ = "smtp"
        }
        arguments.append("--url")
        arguments.append("\(protocol_)://\(profile.host):\(profile.port)")

        // SSL/TLS options
        switch profile.encryption {
        case .ssl:
            arguments.append("--ssl-reqd")
        case .starttls:
            arguments.append("--ssl-reqd")
        case .none:
            break
        }

        // Authentication
        arguments.append("--user")
        arguments.append(profile.username)

        // Sender
        arguments.append("--mail-from")
        arguments.append(fromAddress)

        // Recipients
        for recipient in recipients {
            arguments.append("--mail-rcpt")
            arguments.append(recipient)
        }

        // Upload the EML file
        arguments.append("--upload-file")
        arguments.append(emlPath)

        // Suppress progress meter
        arguments.append("--no-progress-meter")

        // Timeout (30 seconds connect, 120 seconds overall)
        arguments.append("--connect-timeout")
        arguments.append("30")
        arguments.append("--max-time")
        arguments.append("120")

        // Execute curl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw SendError.connectionFailed("Failed to launch curl: \(error)")
        }

        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus

        if exitCode != 0 {
            // Classify the error
            if stderrOutput.lowercased().contains("authentication")
                || stderrOutput.contains("535")
                || stderrOutput.contains("534") {
                throw SendError.authenticationFailed(
                    "SMTP authentication failed: \(stderrOutput)"
                )
            }
            if stderrOutput.lowercased().contains("connect")
                || stderrOutput.contains("couldn't connect")
                || stderrOutput.contains("Connection refused") {
                throw SendError.connectionFailed(
                    "Failed to connect to \(profile.host):\(profile.port): \(stderrOutput)"
                )
            }
            throw SendError.sendFailed(
                "curl exited with code \(exitCode): \(stderrOutput)"
            )
        }

        // Extract Message-ID from the EML data for the result
        let emlString = String(data: emlData, encoding: .utf8) ?? ""
        var messageId: String?
        for line in emlString.components(separatedBy: "\r\n") {
            if line.hasPrefix("Message-ID: ") {
                messageId = String(line.dropFirst("Message-ID: ".count))
                break
            }
        }

        return SendResult(
            success: true,
            messageId: messageId,
            message: "Message sent successfully via \(profile.host):\(profile.port)"
        )
    }
}

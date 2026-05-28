import Foundation

public struct EMLGenerator: Sendable {

    public enum GeneratorError: Error, Sendable {
        case attachmentNotFound(String)
        case attachmentReadFailed(String)
        case encodingFailed
    }

    /// Generate an RFC 5322 / MIME formatted .eml file from a `MailMessage`.
    ///
    /// - Parameters:
    ///   - message: The mail message to serialize.
    ///   - basePath: Optional base path to resolve relative attachment paths against.
    /// - Returns: The raw EML data encoded as UTF-8.
    public static func generate(message: MailMessage, basePath: String?) throws -> Data {
        var lines: [String] = []

        // --- Headers ---

        if let from = message.from {
            lines.append("From: \(from.formatted)")
        }

        if !message.to.isEmpty {
            lines.append("To: \(message.to.map(\.formatted).joined(separator: ", "))")
        }

        if !message.cc.isEmpty {
            lines.append("Cc: \(message.cc.map(\.formatted).joined(separator: ", "))")
        }

        if !message.bcc.isEmpty {
            lines.append("Bcc: \(message.bcc.map(\.formatted).joined(separator: ", "))")
        }

        if let replyTo = message.replyTo {
            lines.append("Reply-To: \(replyTo.formatted)")
        }

        lines.append("Subject: \(message.subject)")
        lines.append("Date: \(rfc2822Date())")
        lines.append("MIME-Version: 1.0")

        let messageId = "<\(UUID().uuidString.lowercased())@ztp.local>"
        lines.append("Message-ID: \(messageId)")

        // --- Render body parts ---

        let plainText = PlainTextRenderer.render(body: message.body, signature: message.signature)
        let htmlText = HTMLMailRenderer.render(body: message.body, signature: message.signature)

        let plainEncoded = QuotedPrintable.encode(plainText)
        let htmlEncoded = QuotedPrintable.encode(htmlText)

        // --- Build MIME body ---

        let hasAttachments = !message.attachments.isEmpty
        let altBoundary = "ztp-alt-\(UUID().uuidString.lowercased())"

        if hasAttachments {
            let mixedBoundary = "ztp-mixed-\(UUID().uuidString.lowercased())"
            lines.append("Content-Type: multipart/mixed; boundary=\"\(mixedBoundary)\"")
            lines.append("")

            // Alternative part (plain + HTML)
            lines.append("--\(mixedBoundary)")
            lines.append("Content-Type: multipart/alternative; boundary=\"\(altBoundary)\"")
            lines.append("")

            appendAlternativeParts(&lines, altBoundary: altBoundary,
                                   plainEncoded: plainEncoded, htmlEncoded: htmlEncoded)

            // Attachment parts
            for attachment in message.attachments {
                let attachmentData = try readAttachmentData(attachment: attachment, basePath: basePath)
                let mime = attachment.mimeType ?? MailAttachment.detectMIME(for: attachment.path)
                let fileName = attachment.displayName

                lines.append("--\(mixedBoundary)")
                lines.append("Content-Type: \(mime); name=\"\(fileName)\"")
                lines.append("Content-Disposition: attachment; filename=\"\(fileName)\"")
                lines.append("Content-Transfer-Encoding: base64")
                lines.append("")
                lines.append(Base64LineEncoder.encode(attachmentData))
                lines.append("")
            }

            lines.append("--\(mixedBoundary)--")
        } else {
            // No attachments: multipart/alternative as top-level
            lines.append("Content-Type: multipart/alternative; boundary=\"\(altBoundary)\"")
            lines.append("")

            appendAlternativeParts(&lines, altBoundary: altBoundary,
                                   plainEncoded: plainEncoded, htmlEncoded: htmlEncoded)
        }

        let emlString = lines.joined(separator: "\r\n")
        guard let data = emlString.data(using: .utf8) else {
            throw GeneratorError.encodingFailed
        }
        return data
    }

    // MARK: - Private Helpers

    private static func appendAlternativeParts(
        _ lines: inout [String],
        altBoundary: String,
        plainEncoded: String,
        htmlEncoded: String
    ) {
        // Plain text part
        lines.append("--\(altBoundary)")
        lines.append("Content-Type: text/plain; charset=utf-8")
        lines.append("Content-Transfer-Encoding: quoted-printable")
        lines.append("")
        lines.append(plainEncoded)
        lines.append("")

        // HTML part
        lines.append("--\(altBoundary)")
        lines.append("Content-Type: text/html; charset=utf-8")
        lines.append("Content-Transfer-Encoding: quoted-printable")
        lines.append("")
        lines.append(htmlEncoded)
        lines.append("")

        lines.append("--\(altBoundary)--")
        lines.append("")
    }

    private static func readAttachmentData(attachment: MailAttachment, basePath: String?) throws -> Data {
        var filePath = attachment.path

        // Resolve relative paths against basePath
        if !filePath.hasPrefix("/") {
            if let base = basePath {
                let baseClean = base.hasSuffix("/") ? String(base.dropLast()) : base
                filePath = "\(baseClean)/\(filePath)"
            }
        }

        // Expand tilde
        if filePath.hasPrefix("~/") {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            filePath = home + String(filePath.dropFirst())
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            throw GeneratorError.attachmentNotFound(filePath)
        }

        guard let data = fileManager.contents(atPath: filePath) else {
            throw GeneratorError.attachmentReadFailed(filePath)
        }

        return data
    }

    /// Format the current date as RFC 2822.
    /// Example: `Wed, 28 May 2026 10:30:00 -0400`
    private static func rfc2822Date() -> String {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            in: TimeZone.current, from: now
        )

        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second else {
            // Fallback: use DateFormatter
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.string(from: now)
        }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        let dayName = dayNames[weekday - 1]
        let monthName = monthNames[month - 1]

        let tz = TimeZone.current
        let offset = tz.secondsFromGMT(for: now)
        let tzHours = abs(offset) / 3600
        let tzMinutes = (abs(offset) % 3600) / 60
        let tzSign = offset >= 0 ? "+" : "-"
        let tzString = String(format: "%@%02d%02d", tzSign, tzHours, tzMinutes)

        return String(format: "%@, %02d %@ %04d %02d:%02d:%02d %@",
                      dayName, day, monthName, year, hour, minute, second, tzString)
    }
}

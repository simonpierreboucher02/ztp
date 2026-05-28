import Foundation

public struct AppleMailDraft: Sendable {

    public struct DraftResult: Sendable {
        public let success: Bool
        public let message: String

        public init(success: Bool, message: String) {
            self.success = success
            self.message = message
        }
    }

    public enum DraftError: Error, Sendable {
        case scriptFailed(String)
        case attachmentNotFound(String)
        case osascriptNotFound
    }

    /// Create a draft message in Apple Mail using AppleScript.
    ///
    /// The body is rendered as plain text via `PlainTextRenderer`.
    /// Attachments are added if their files exist on disk.
    ///
    /// - Parameters:
    ///   - message: The mail message to draft.
    ///   - basePath: Optional base path for resolving relative attachment paths.
    /// - Returns: A `DraftResult` indicating success or failure.
    public static func createDraft(message: MailMessage, basePath: String?) throws -> DraftResult {
        // Verify osascript is available
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: "/usr/bin/osascript") else {
            throw DraftError.osascriptNotFound
        }

        // Render body as plain text
        let bodyText = PlainTextRenderer.render(body: message.body, signature: message.signature)

        // Resolve attachment paths and verify they exist
        var resolvedAttachments: [(path: String, name: String)] = []
        for attachment in message.attachments {
            let resolved = resolvePath(attachment.path, basePath: basePath)
            guard fileManager.fileExists(atPath: resolved) else {
                throw DraftError.attachmentNotFound(resolved)
            }
            resolvedAttachments.append((path: resolved, name: attachment.displayName))
        }

        // Build AppleScript
        let script = buildAppleScript(
            subject: message.subject,
            body: bodyText,
            toRecipients: message.to,
            ccRecipients: message.cc,
            bccRecipients: message.bcc,
            attachments: resolvedAttachments
        )

        // Execute via osascript
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw DraftError.scriptFailed("Failed to launch osascript: \(error)")
        }

        process.waitUntilExit()

        let exitCode = process.terminationStatus

        if exitCode != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""
            throw DraftError.scriptFailed("osascript exited with code \(exitCode): \(stderrOutput)")
        }

        let recipientCount = message.to.count + message.cc.count + message.bcc.count
        let attachmentCount = resolvedAttachments.count
        var resultMessage = "Draft created in Apple Mail"
        resultMessage += " with \(recipientCount) recipient\(recipientCount == 1 ? "" : "s")"
        if attachmentCount > 0 {
            resultMessage += " and \(attachmentCount) attachment\(attachmentCount == 1 ? "" : "s")"
        }

        return DraftResult(success: true, message: resultMessage)
    }

    // MARK: - Private Helpers

    private static func buildAppleScript(
        subject: String,
        body: String,
        toRecipients: [MailAddress],
        ccRecipients: [MailAddress],
        bccRecipients: [MailAddress],
        attachments: [(path: String, name: String)]
    ) -> String {
        let escapedSubject = escapeAppleScript(subject)
        let escapedBody = escapeAppleScript(body)

        var script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:true}
            tell newMessage
        """

        // To recipients
        for recipient in toRecipients {
            let addr = escapeAppleScript(recipient.email)
            if let name = recipient.name, !name.isEmpty {
                let escapedName = escapeAppleScript(name)
                script += """
                \n        make new to recipient at end of to recipients with properties {address:"\(addr)", name:"\(escapedName)"}
                """
            } else {
                script += """
                \n        make new to recipient at end of to recipients with properties {address:"\(addr)"}
                """
            }
        }

        // CC recipients
        for recipient in ccRecipients {
            let addr = escapeAppleScript(recipient.email)
            if let name = recipient.name, !name.isEmpty {
                let escapedName = escapeAppleScript(name)
                script += """
                \n        make new cc recipient at end of cc recipients with properties {address:"\(addr)", name:"\(escapedName)"}
                """
            } else {
                script += """
                \n        make new cc recipient at end of cc recipients with properties {address:"\(addr)"}
                """
            }
        }

        // BCC recipients
        for recipient in bccRecipients {
            let addr = escapeAppleScript(recipient.email)
            if let name = recipient.name, !name.isEmpty {
                let escapedName = escapeAppleScript(name)
                script += """
                \n        make new bcc recipient at end of bcc recipients with properties {address:"\(addr)", name:"\(escapedName)"}
                """
            } else {
                script += """
                \n        make new bcc recipient at end of bcc recipients with properties {address:"\(addr)"}
                """
            }
        }

        script += "\n    end tell"

        // Attachments
        for attachment in attachments {
            let escapedPath = escapeAppleScript(attachment.path)
            script += """
            \n    tell content of newMessage
                make new attachment with properties {file name:POSIX file "\(escapedPath)"} at after last paragraph
            end tell
            """
        }

        script += "\n    activate"
        script += "\nend tell"

        return script
    }

    /// Escape a string for safe inclusion in an AppleScript double-quoted string.
    ///
    /// AppleScript requires backslashes and double quotes to be escaped.
    private static func escapeAppleScript(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        // Newlines need to be represented as AppleScript line breaks
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }

    /// Resolve a file path, expanding tildes and resolving relative paths against basePath.
    private static func resolvePath(_ path: String, basePath: String?) -> String {
        var resolved = path

        // Expand tilde
        if resolved.hasPrefix("~/") {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            resolved = home + String(resolved.dropFirst())
        }

        // Resolve relative paths
        if !resolved.hasPrefix("/") {
            if let base = basePath {
                let baseClean = base.hasSuffix("/") ? String(base.dropLast()) : base
                resolved = "\(baseClean)/\(resolved)"
            }
        }

        return resolved
    }
}

import Foundation

public struct MailValidator: Sendable {

    // MARK: - Result types

    public struct ValidationResult: Codable, Sendable {
        public let valid: Bool
        public let errors: [ValidationError]
        public let warnings: [ValidationWarning]

        public init(valid: Bool, errors: [ValidationError], warnings: [ValidationWarning]) {
            self.valid = valid
            self.errors = errors
            self.warnings = warnings
        }
    }

    public struct ValidationError: Codable, Sendable {
        public let code: String
        public let message: String
        public let path: String?
        public let hint: String?

        public init(code: String, message: String, path: String? = nil, hint: String? = nil) {
            self.code = code
            self.message = message
            self.path = path
            self.hint = hint
        }
    }

    public struct ValidationWarning: Codable, Sendable {
        public let code: String
        public let message: String

        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }

    // MARK: - Email validation helper

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^@]+@[^@]+\.[^@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private static func resolvedPath(_ filePath: String, basePath: String?) -> String {
        if filePath.hasPrefix("/") {
            return filePath
        }
        guard let base = basePath, !base.isEmpty else {
            return filePath
        }
        let baseURL = URL(fileURLWithPath: base, isDirectory: true)
        return baseURL.appendingPathComponent(filePath).path
    }

    // MARK: - Validate MailMessage

    public static func validate(message: MailMessage, basePath: String?) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Error: at least one recipient in `to`
        if message.to.isEmpty {
            errors.append(ValidationError(
                code: "NO_RECIPIENTS",
                message: "At least one recipient is required in 'to'",
                path: "message.to",
                hint: "Add at least one email address to the 'to' field"
            ))
        }

        // Error: all email addresses are valid format
        if let from = message.from, !isValidEmail(from.email) {
            errors.append(ValidationError(
                code: "INVALID_EMAIL",
                message: "Invalid email address: \(from.email)",
                path: "message.from",
                hint: "Email must contain '@' and at least one dot after '@'"
            ))
        }

        for (index, addr) in message.to.enumerated() {
            if !isValidEmail(addr.email) {
                errors.append(ValidationError(
                    code: "INVALID_EMAIL",
                    message: "Invalid email address: \(addr.email)",
                    path: "message.to[\(index)]",
                    hint: "Email must contain '@' and at least one dot after '@'"
                ))
            }
        }

        for (index, addr) in message.cc.enumerated() {
            if !isValidEmail(addr.email) {
                errors.append(ValidationError(
                    code: "INVALID_EMAIL",
                    message: "Invalid email address: \(addr.email)",
                    path: "message.cc[\(index)]",
                    hint: "Email must contain '@' and at least one dot after '@'"
                ))
            }
        }

        for (index, addr) in message.bcc.enumerated() {
            if !isValidEmail(addr.email) {
                errors.append(ValidationError(
                    code: "INVALID_EMAIL",
                    message: "Invalid email address: \(addr.email)",
                    path: "message.bcc[\(index)]",
                    hint: "Email must contain '@' and at least one dot after '@'"
                ))
            }
        }

        if let replyTo = message.replyTo, !isValidEmail(replyTo.email) {
            errors.append(ValidationError(
                code: "INVALID_EMAIL",
                message: "Invalid email address: \(replyTo.email)",
                path: "message.reply_to",
                hint: "Email must contain '@' and at least one dot after '@'"
            ))
        }

        // Error: subject is non-empty
        if message.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                code: "EMPTY_SUBJECT",
                message: "Subject must not be empty",
                path: "message.subject",
                hint: "Provide a non-empty subject line"
            ))
        }

        // Error: body content is non-empty
        if message.body.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                code: "EMPTY_BODY",
                message: "Body content must not be empty",
                path: "message.body.content",
                hint: "Provide non-empty body content"
            ))
        }

        // Attachment checks
        let fm = FileManager.default
        for (index, attachment) in message.attachments.enumerated() {
            let resolved = resolvedPath(attachment.path, basePath: basePath)

            // Error: attachment file exists on disk
            if !fm.fileExists(atPath: resolved) {
                errors.append(ValidationError(
                    code: "ATTACHMENT_NOT_FOUND",
                    message: "Attachment file not found: \(attachment.path)",
                    path: "message.attachments[\(index)]",
                    hint: "Verify the file path exists or use an absolute path"
                ))
            } else {
                // Check file size
                if let attrs = try? fm.attributesOfItem(atPath: resolved),
                   let size = attrs[.size] as? UInt64 {
                    let sizeMB = Double(size) / (1024.0 * 1024.0)
                    if sizeMB > 100 {
                        errors.append(ValidationError(
                            code: "ATTACHMENT_TOO_LARGE",
                            message: "Attachment '\(attachment.displayName)' is \(Int(sizeMB))MB (max 100MB)",
                            path: "message.attachments[\(index)]",
                            hint: "Reduce file size or use a file sharing service"
                        ))
                    } else if sizeMB > 25 {
                        warnings.append(ValidationWarning(
                            code: "LARGE_ATTACHMENT",
                            message: "Attachment '\(attachment.displayName)' is \(Int(sizeMB))MB; many mail servers reject messages over 25MB"
                        ))
                    }
                }
            }
        }

        // Warning: no `from` address set
        if message.from == nil {
            warnings.append(ValidationWarning(
                code: "NO_FROM",
                message: "No 'from' address set; the mail client or server will choose a default sender"
            ))
        }

        // Warning: empty cc/bcc (only if the fields are truly empty arrays -- always true for MailMessage defaults)
        // These are informational; skip if irrelevant.

        // Warning: very long subject (> 200 chars)
        if message.subject.count > 200 {
            warnings.append(ValidationWarning(
                code: "LONG_SUBJECT",
                message: "Subject is \(message.subject.count) characters; subjects over 200 characters may be truncated by mail clients"
            ))
        }

        // Warning: body > 100KB
        if message.body.content.utf8.count > 100 * 1024 {
            let sizeKB = message.body.content.utf8.count / 1024
            warnings.append(ValidationWarning(
                code: "LARGE_BODY",
                message: "Body content is \(sizeKB)KB; very large bodies may cause delivery issues"
            ))
        }

        // Warning: many recipients (> 50)
        if message.recipientCount > 50 {
            warnings.append(ValidationWarning(
                code: "MANY_RECIPIENTS",
                message: "Message has \(message.recipientCount) recipients; some mail servers limit recipient count"
            ))
        }

        return ValidationResult(
            valid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Validate MailSpec

    public static func validate(spec: MailSpec, basePath: String?) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Error: version must be "ztp-mail/0.1"
        if spec.version != "ztp-mail/0.1" {
            errors.append(ValidationError(
                code: "INVALID_VERSION",
                message: "Expected version 'ztp-mail/0.1', got '\(spec.version)'",
                path: "version",
                hint: "Set version to 'ztp-mail/0.1'"
            ))
        }

        // Convert to MailMessage and validate that
        do {
            let message = try spec.toMessage()
            let messageResult = validate(message: message, basePath: basePath)
            errors.append(contentsOf: messageResult.errors)
            warnings.append(contentsOf: messageResult.warnings)
        } catch {
            errors.append(ValidationError(
                code: "SPEC_CONVERSION_FAILED",
                message: "Failed to convert spec to message: \(error.localizedDescription)",
                path: nil,
                hint: "Check that all fields are properly formatted"
            ))
        }

        return ValidationResult(
            valid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Validate JSON Data

    public static func validate(jsonData: Data, basePath: String?) -> ValidationResult {
        do {
            let spec = try MailSpec.decode(from: jsonData)
            return validate(spec: spec, basePath: basePath)
        } catch {
            return ValidationResult(
                valid: false,
                errors: [ValidationError(
                    code: "JSON_DECODE_FAILED",
                    message: "Failed to decode JSON: \(error.localizedDescription)",
                    path: nil,
                    hint: "Ensure the JSON conforms to the MailSpec schema"
                )],
                warnings: []
            )
        }
    }
}

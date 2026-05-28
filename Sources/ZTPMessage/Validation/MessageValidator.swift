import Foundation

public struct MessageValidator: Sendable {

    // MARK: - Result Types

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

    // MARK: - Validate ShortMessage

    public static func validate(message: ShortMessage) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Check recipients
        if message.to.isEmpty {
            errors.append(ValidationError(
                code: "NO_RECIPIENTS",
                message: "Message must have at least one recipient",
                path: "to",
                hint: "Add at least one recipient with a valid address"
            ))
        }

        for (index, recipient) in message.to.enumerated() {
            if recipient.address.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(ValidationError(
                    code: "EMPTY_ADDRESS",
                    message: "Recipient at index \(index) has an empty address",
                    path: "to[\(index)].address",
                    hint: "Provide a phone number or email address"
                ))
            }
        }

        // Check body
        if message.body.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                code: "EMPTY_BODY",
                message: "Message body must not be empty",
                path: "body.content",
                hint: "Provide message content"
            ))
        }

        // Warnings
        if message.characterCount > 1000 {
            warnings.append(ValidationWarning(
                code: "LONG_MESSAGE",
                message: "Message is \(message.characterCount) characters — consider shortening for SMS"
            ))
        }

        if message.recipientCount > 10 {
            warnings.append(ValidationWarning(
                code: "MANY_RECIPIENTS",
                message: "Message has \(message.recipientCount) recipients — verify this is intentional"
            ))
        }

        return ValidationResult(valid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Validate MessageSpec

    public static func validate(spec: MessageSpec) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Version check
        if spec.version != "ztp-message/0.1" {
            errors.append(ValidationError(
                code: "UNSUPPORTED_VERSION",
                message: "Unsupported spec version: \(spec.version)",
                path: "version",
                hint: "Use version \"ztp-message/0.1\""
            ))
        }

        // Channel check
        if let channel = spec.message.channel {
            if MessageChannel(rawValue: channel) == nil {
                errors.append(ValidationError(
                    code: "INVALID_CHANNEL",
                    message: "Unsupported channel: \(channel)",
                    path: "message.channel",
                    hint: "Use \"imessage\" or \"sms\""
                ))
            }
        }

        // Recipients
        if spec.message.to.isEmpty {
            errors.append(ValidationError(
                code: "NO_RECIPIENTS",
                message: "Message must have at least one recipient",
                path: "message.to",
                hint: "Add at least one recipient"
            ))
        }

        for (index, recipient) in spec.message.to.enumerated() {
            if recipient.address.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(ValidationError(
                    code: "EMPTY_ADDRESS",
                    message: "Recipient at index \(index) has an empty address",
                    path: "message.to[\(index)].address",
                    hint: "Provide a phone number or email address"
                ))
            }
        }

        // Body
        if spec.message.body.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && spec.message.template == nil {
            errors.append(ValidationError(
                code: "EMPTY_BODY",
                message: "Message body must not be empty (or provide a template)",
                path: "message.body.content",
                hint: "Provide message content or specify a template name"
            ))
        }

        // Warnings
        if spec.message.body.content.count > 1000 {
            warnings.append(ValidationWarning(
                code: "LONG_MESSAGE",
                message: "Message body is \(spec.message.body.content.count) characters — consider shortening"
            ))
        }

        if spec.message.to.count > 10 {
            warnings.append(ValidationWarning(
                code: "MANY_RECIPIENTS",
                message: "Message has \(spec.message.to.count) recipients — verify this is intentional"
            ))
        }

        return ValidationResult(valid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Validate JSON Data

    public static func validate(jsonData: Data) -> ValidationResult {
        do {
            let decoder = JSONDecoder()
            let spec = try decoder.decode(MessageSpec.self, from: jsonData)
            return validate(spec: spec)
        } catch {
            return ValidationResult(
                valid: false,
                errors: [
                    ValidationError(
                        code: "INVALID_JSON",
                        message: "Failed to parse message spec: \(error.localizedDescription)",
                        path: nil,
                        hint: "Ensure the JSON conforms to the MessageSpec schema"
                    )
                ],
                warnings: []
            )
        }
    }
}

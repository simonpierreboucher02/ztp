import Foundation

public struct URLValidator: Sendable {

    public struct ValidationResult: Codable, Sendable {
        public let valid: Bool
        public let errors: [ValidationError]

        public init(valid: Bool, errors: [ValidationError]) {
            self.valid = valid
            self.errors = errors
        }
    }

    public struct ValidationError: Codable, Sendable {
        public let code: String
        public let message: String
        public let hint: String?

        public init(code: String, message: String, hint: String?) {
            self.code = code
            self.message = message
            self.hint = hint
        }
    }

    public static func validate(urlString: String) -> ValidationResult {
        var errors: [ValidationError] = []

        // Check non-empty
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errors.append(ValidationError(
                code: "EMPTY_URL",
                message: "URL must not be empty.",
                hint: "Provide a fully-qualified URL such as https://example.com"
            ))
            return ValidationResult(valid: false, errors: errors)
        }

        // Check parseable
        guard let url = URL(string: trimmed) else {
            errors.append(ValidationError(
                code: "INVALID_URL",
                message: "The string could not be parsed as a valid URL.",
                hint: "Make sure the URL is properly encoded and well-formed."
            ))
            return ValidationResult(valid: false, errors: errors)
        }

        // Check scheme
        let scheme = url.scheme?.lowercased()
        if scheme == nil {
            errors.append(ValidationError(
                code: "MISSING_SCHEME",
                message: "URL is missing a scheme.",
                hint: "Add https:// or http:// to the beginning of the URL."
            ))
        } else if scheme != "http" && scheme != "https" {
            errors.append(ValidationError(
                code: "INVALID_SCHEME",
                message: "Scheme '\(scheme!)' is not allowed. Only http and https are supported.",
                hint: "Use https:// or http:// instead of \(scheme!)://."
            ))
        }

        // Check host
        if url.host == nil || url.host?.isEmpty == true {
            errors.append(ValidationError(
                code: "MISSING_HOST",
                message: "URL has no host component.",
                hint: "Provide a host such as example.com."
            ))
        }

        // Warn on localhost (warning only — does not invalidate)
        if let host = url.host?.lowercased(),
           host == "localhost" || host == "127.0.0.1" || host == "::1" {
            errors.append(ValidationError(
                code: "LOCALHOST_WARNING",
                message: "URL points to localhost, which may not be reachable in production.",
                hint: "Use a publicly accessible hostname if this is for production use."
            ))
            // localhost is a warning, so only invalid if other errors exist
            let hardErrors = errors.filter { $0.code != "LOCALHOST_WARNING" }
            return ValidationResult(valid: hardErrors.isEmpty, errors: errors)
        }

        let valid = errors.isEmpty
        return ValidationResult(valid: valid, errors: errors)
    }
}

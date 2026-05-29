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

    public static func validate(urlString: String, allowPrivateHosts: Bool = false) -> ValidationResult {
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

        // SSRF guard: block private / loopback / link-local / reserved hosts
        // unless explicitly allowed. Secure by default.
        if let host = url.host?.lowercased(), isBlockedHost(host) {
            if allowPrivateHosts {
                errors.append(ValidationError(
                    code: "PRIVATE_HOST_WARNING",
                    message: "URL points to a private/loopback host (\(host)).",
                    hint: "Allowed because private hosts were explicitly permitted."
                ))
            } else {
                errors.append(ValidationError(
                    code: "BLOCKED_HOST",
                    message: "URL targets a private, loopback, or reserved host (\(host)) — blocked to prevent SSRF.",
                    hint: "Pass an explicit allow-private flag only for trusted internal use."
                ))
            }
        }

        let hardErrors = errors.filter { $0.code.hasSuffix("_WARNING") == false }
        return ValidationResult(valid: hardErrors.isEmpty, errors: errors)
    }

    /// Whether a host is private/loopback/link-local/reserved and should be
    /// blocked by the SSRF guard.
    static func isBlockedHost(_ host: String) -> Bool {
        let h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        // Hostname-based loopback / metadata.
        if h == "localhost" || h.hasSuffix(".localhost") { return true }
        if h == "metadata.google.internal" { return true }

        // IPv6 loopback / unique-local (fc00::/7) / link-local (fe80::/10).
        if h == "::1" || h == "::" { return true }
        if h.hasPrefix("fc") || h.hasPrefix("fd") || h.hasPrefix("fe8") || h.hasPrefix("fe9")
            || h.hasPrefix("fea") || h.hasPrefix("feb") { return true }

        // IPv4 literal ranges.
        let parts = h.split(separator: ".")
        if parts.count == 4, let a = Int(parts[0]), let b = Int(parts[1]),
           parts[2].allSatisfy(\.isNumber), parts[3].allSatisfy(\.isNumber) {
            if a == 10 { return true }                          // 10.0.0.0/8
            if a == 127 { return true }                         // loopback
            if a == 0 { return true }                           // 0.0.0.0/8
            if a == 172, (16...31).contains(b) { return true }  // 172.16.0.0/12
            if a == 192, b == 168 { return true }               // 192.168.0.0/16
            if a == 169, b == 254 { return true }               // link-local + 169.254.169.254 metadata
            if a == 100, (64...127).contains(b) { return true }  // CGNAT 100.64.0.0/10
        }
        return false
    }
}

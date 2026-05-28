import Foundation

public struct MailAddress: Codable, Sendable, Equatable, Hashable {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }

    // MARK: - Formatted output

    public var formatted: String {
        if let name = name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }

    // MARK: - Parsing

    /// Parse a string like `"Name <email>"` or a bare `"email"`.
    public static func parse(_ string: String) -> MailAddress? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try "Name <email>" form
        if let openAngle = trimmed.lastIndex(of: "<"),
           let closeAngle = trimmed.lastIndex(of: ">"),
           openAngle < closeAngle {
            let emailPart = String(trimmed[trimmed.index(after: openAngle)..<closeAngle])
                .trimmingCharacters(in: .whitespaces)
            let namePart = String(trimmed[trimmed.startIndex..<openAngle])
                .trimmingCharacters(in: .whitespaces)
            let name = namePart.isEmpty ? nil : namePart
            let addr = MailAddress(email: emailPart, name: name)
            return addr.isValid ? addr : nil
        }

        // Bare email
        let addr = MailAddress(email: trimmed)
        return addr.isValid ? addr : nil
    }

    // MARK: - Validation

    /// Basic email validation: local@domain with at least one dot in domain.
    public var isValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

import Foundation

// MARK: - MessageTemplate

public struct MessageTemplate: Codable, Sendable {
    public let name: String
    public let pattern: String
    public let description: String

    public init(name: String, pattern: String, description: String) {
        self.name = name
        self.pattern = pattern
        self.description = description
    }
}

// MARK: - Template Engine Errors

public enum MessageTemplateError: Error, Sendable {
    case missingVariable(String)
}

// MARK: - MessageTemplateEngine

public struct MessageTemplateEngine: Sendable {

    public static let builtInTemplates: [MessageTemplate] = [
        MessageTemplate(
            name: "appointment-confirmation",
            pattern: "Bonjour {{name}}, je confirme notre rendez-vous {{date}} à {{time}}.",
            description: "Confirm an appointment"
        ),
        MessageTemplate(
            name: "pipeline-status",
            pattern: "{{status}}: {{pipeline}} completed. {{details}}",
            description: "Notify pipeline completion"
        ),
        MessageTemplate(
            name: "report-ready",
            pattern: "Bonjour {{name}}, le rapport {{report}} est prêt. {{link}}",
            description: "Notify a report is ready"
        ),
        MessageTemplate(
            name: "quick-reminder",
            pattern: "Rappel: {{reminder}}. Prévu {{when}}.",
            description: "Quick reminder message"
        ),
    ]

    /// Render a template pattern by substituting `{{key}}` placeholders with values.
    /// Throws `MessageTemplateError.missingVariable` if a referenced variable has no value.
    public static func render(template: String, variables: [String: String]) throws -> String {
        var result = template
        // Find all {{key}} placeholders
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: nsRange)

        // Collect all referenced keys and check they exist
        var replacements: [(range: Range<String.Index>, key: String, value: String)] = []
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            let key = String(result[keyRange]).trimmingCharacters(in: .whitespaces)
            guard let value = variables[key] else {
                throw MessageTemplateError.missingVariable(key)
            }
            replacements.append((range: fullRange, key: key, value: value))
        }

        // Apply replacements in reverse order to preserve indices
        for replacement in replacements {
            result.replaceSubrange(replacement.range, with: replacement.value)
        }

        return result
    }

    /// List all built-in templates.
    public static func list() -> [MessageTemplate] {
        builtInTemplates
    }

    /// Get a built-in template by name.
    public static func get(named name: String) -> MessageTemplate? {
        builtInTemplates.first { $0.name == name }
    }
}

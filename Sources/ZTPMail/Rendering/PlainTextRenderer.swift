import Foundation

public struct PlainTextRenderer: Sendable {

    /// Render a mail body (with optional signature) as plain text.
    public static func render(body: MailBody, signature: String?) -> String {
        var text: String

        switch body.type {
        case .plain:
            text = body.content

        case .markdown:
            text = stripMarkdown(body.content)

        case .html:
            text = stripHTML(body.content)
        }

        if let sig = signature, !sig.isEmpty {
            text += "\n\n" + sig
        }

        return text
    }

    // MARK: - Private

    /// Strip Markdown syntax to produce plain text.
    private static func stripMarkdown(_ markdown: String) -> String {
        var result = markdown

        // Remove heading markers
        result = regexReplace(in: result, pattern: "^#{1,3}\\s+", with: "")

        // Bold **text** → text
        result = regexReplace(in: result, pattern: "\\*\\*([^*]+)\\*\\*", with: "$1")

        // Italic *text* → text
        result = regexReplace(in: result, pattern: "\\*([^*]+)\\*", with: "$1")

        // Inline code `code` → code
        result = regexReplace(in: result, pattern: "`([^`]+)`", with: "$1")

        // Links [text](url) → text (url)
        result = regexReplace(in: result, pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "$1 ($2)")

        // Horizontal rules
        result = regexReplace(in: result, pattern: "^---$", with: "---")
        result = regexReplace(in: result, pattern: "^\\*\\*\\*$", with: "---")
        result = regexReplace(in: result, pattern: "^___$", with: "---")

        // Unordered list items: "- item" → "  - item" (keep as-is, already readable)
        // Ordered list items: "1. item" → keep as-is

        return result
    }

    /// Strip HTML tags to produce plain text.
    private static func stripHTML(_ html: String) -> String {
        var result = html

        // Replace <br> variants with newlines
        result = regexReplace(in: result, pattern: "<br\\s*/?>", with: "\n")

        // Replace block-level closing tags with newlines
        result = regexReplace(in: result, pattern: "</p>", with: "\n\n")
        result = regexReplace(in: result, pattern: "</div>", with: "\n")
        result = regexReplace(in: result, pattern: "</li>", with: "\n")
        result = regexReplace(in: result, pattern: "</h[1-6]>", with: "\n\n")

        // Strip all remaining HTML tags
        result = regexReplace(in: result, pattern: "<[^>]+>", with: "")

        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")

        // Collapse multiple blank lines into two
        result = regexReplace(in: result, pattern: "\n{3,}", with: "\n\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Helper to perform regex replacement.
    private static func regexReplace(
        in string: String,
        pattern: String,
        with template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else {
            return string
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: template)
    }
}

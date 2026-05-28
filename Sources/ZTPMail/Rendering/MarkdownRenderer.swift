import Foundation

public struct MarkdownMailRenderer: Sendable {

    /// Render Markdown content into a full HTML email document.
    public static func render(_ markdown: String) -> String {
        let htmlBody = convertMarkdownToHTML(markdown)
        return wrapInTemplate(htmlBody)
    }

    // MARK: - Private

    private static func convertMarkdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line — paragraph break
            if trimmed.isEmpty {
                result.append("")
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append("<hr>")
                i += 1
                continue
            }

            // Headings
            if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                result.append("<h3>\(processInline(text))</h3>")
                i += 1
                continue
            }
            if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                result.append("<h2>\(processInline(text))</h2>")
                i += 1
                continue
            }
            if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                result.append("<h1>\(processInline(text))</h1>")
                i += 1
                continue
            }

            // Unordered list — group consecutive lines starting with "- "
            if trimmed.hasPrefix("- ") {
                var items: [String] = []
                while i < lines.count {
                    let li = lines[i].trimmingCharacters(in: .whitespaces)
                    guard li.hasPrefix("- ") else { break }
                    items.append(processInline(String(li.dropFirst(2))))
                    i += 1
                }
                let listItems = items.map { "<li>\($0)</li>" }.joined()
                result.append("<ul>\(listItems)</ul>")
                continue
            }

            // Ordered list — group consecutive lines matching "N. "
            if isOrderedListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let li = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isOrderedListItem(li) else { break }
                    if let dotSpace = li.firstIndex(of: ".") {
                        let afterDot = li[li.index(after: dotSpace)...]
                            .trimmingCharacters(in: .whitespaces)
                        items.append(processInline(String(afterDot)))
                    }
                    i += 1
                }
                let listItems = items.map { "<li>\($0)</li>" }.joined()
                result.append("<ol>\(listItems)</ol>")
                continue
            }

            // Regular paragraph — collect consecutive non-blank, non-special lines
            var paragraphLines: [String] = []
            while i < lines.count {
                let pl = lines[i]
                let pt = pl.trimmingCharacters(in: .whitespaces)
                if pt.isEmpty || pt.hasPrefix("# ") || pt.hasPrefix("## ") || pt.hasPrefix("### ")
                    || pt.hasPrefix("- ") || isOrderedListItem(pt)
                    || pt == "---" || pt == "***" || pt == "___" {
                    break
                }
                paragraphLines.append(processInline(pt))
                i += 1
            }
            if !paragraphLines.isEmpty {
                result.append("<p>\(paragraphLines.joined(separator: "<br>"))</p>")
            }
        }

        return result.joined(separator: "\n")
    }

    /// Check if a trimmed line matches an ordered list pattern like "1. text"
    private static func isOrderedListItem(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let prefix = line[line.startIndex..<dotIndex]
        guard !prefix.isEmpty else { return false }
        for ch in prefix {
            guard ch.isNumber else { return false }
        }
        // Must have a space after the dot
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return false }
        return true
    }

    /// Process inline Markdown elements: bold, italic, code, links
    private static func processInline(_ text: String) -> String {
        var result = HTMLEscaping.escape(text)

        // Inline code: `code`
        result = replacePattern(in: result, pattern: "`([^`]+)`") { match in
            let inner = String(match.dropFirst().dropLast())
            return "<code>\(inner)</code>"
        }

        // Bold: **text**
        result = replacePattern(in: result, pattern: "\\*\\*([^*]+)\\*\\*") { match in
            let inner = String(match.dropFirst(2).dropLast(2))
            return "<strong>\(inner)</strong>"
        }

        // Italic: *text*
        result = replacePattern(in: result, pattern: "\\*([^*]+)\\*") { match in
            let inner = String(match.dropFirst().dropLast())
            return "<em>\(inner)</em>"
        }

        // Links: [text](url)
        result = replacePattern(in: result, pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)") { _ in
            "" // handled specially below
        }
        // Re-do links with a proper approach
        result = processLinks(result)

        return result
    }

    /// Replace regex matches using a transform closure.
    private static func replacePattern(
        in string: String,
        pattern: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string
        }
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))

        var result = string
        // Process in reverse to preserve ranges
        for match in matches.reversed() {
            let matchedString = nsString.substring(with: match.range)
            let replacement = transform(matchedString)
            let startIndex = result.index(result.startIndex, offsetBy: match.range.location)
            let endIndex = result.index(startIndex, offsetBy: match.range.length)
            result.replaceSubrange(startIndex..<endIndex, with: replacement)
        }
        return result
    }

    /// Process Markdown links [text](url) into <a> tags.
    private static func processLinks(_ string: String) -> String {
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string
        }
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))

        var result = string
        for match in matches.reversed() {
            guard match.numberOfRanges == 3 else { continue }
            let text = nsString.substring(with: match.range(at: 1))
            let url = nsString.substring(with: match.range(at: 2))
            let replacement = "<a href=\"\(url)\">\(text)</a>"
            let startIndex = result.index(result.startIndex, offsetBy: match.range.location)
            let endIndex = result.index(startIndex, offsetBy: match.range.length)
            result.replaceSubrange(startIndex..<endIndex, with: replacement)
        }
        return result
    }

    /// Wrap HTML content in the email template.
    private static func wrapInTemplate(_ content: String) -> String {
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, Arial, sans-serif; font-size: 14px; line-height: 1.6; color: #333; max-width: 600px; }
        h1 { font-size: 22px; } h2 { font-size: 18px; } h3 { font-size: 16px; }
        a { color: #2563EB; } code { background: #f1f5f9; padding: 2px 4px; border-radius: 3px; }
        hr { border: none; border-top: 1px solid #e5e7eb; margin: 20px 0; }
        </style></head><body>\(content)</body></html>
        """
    }
}

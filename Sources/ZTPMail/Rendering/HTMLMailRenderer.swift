import Foundation

public struct HTMLMailRenderer: Sendable {

    /// Render a mail body (with optional signature) into a full HTML document.
    public static func render(body: MailBody, signature: String?) -> String {
        switch body.type {
        case .html:
            // Return HTML content as-is, appending signature if present
            if let sig = signature, !sig.isEmpty {
                let escapedSig = HTMLEscaping.escape(sig)
                    .replacingOccurrences(of: "\n", with: "<br>")
                return body.content + "<br><br>" + escapedSig
            }
            return body.content

        case .markdown:
            // Render markdown through the markdown renderer
            var markdown = body.content
            if let sig = signature, !sig.isEmpty {
                markdown += "\n\n" + sig
            }
            return MarkdownMailRenderer.render(markdown)

        case .plain:
            // Escape HTML entities, convert newlines to <br>, wrap in template
            var text = body.content
            if let sig = signature, !sig.isEmpty {
                text += "\n\n" + sig
            }
            let escaped = HTMLEscaping.escape(text)
                .replacingOccurrences(of: "\n", with: "<br>")
            return wrapInTemplate(escaped)
        }
    }

    // MARK: - Private

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

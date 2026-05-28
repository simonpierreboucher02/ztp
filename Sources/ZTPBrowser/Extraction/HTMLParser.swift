import Foundation

public struct HTMLContentParser: Sendable {

    // MARK: - Title

    public static func extractTitle(from html: String) -> String? {
        guard let match = html.range(
            of: "<title[^>]*>(.*?)</title>",
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }

        let raw = String(html[match])
        // Strip the <title> tags
        let inner = raw
            .replacingOccurrences(of: "<title[^>]*>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</title>", with: "", options: [.caseInsensitive])
        let decoded = decodeHTMLEntities(inner)
        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Meta Description

    public static func extractMetaDescription(from html: String) -> String? {
        return extractMetaContent(from: html, name: "description")
    }

    // MARK: - Canonical URL

    public static func extractCanonicalURL(from html: String) -> String? {
        // <link rel="canonical" href="...">
        let pattern = #"<link\s[^>]*rel\s*=\s*["']canonical["'][^>]*>"#
        guard let tagRange = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let tag = String(html[tagRange])
        return extractAttribute(named: "href", from: tag)
    }

    // MARK: - Open Graph

    public static func extractOpenGraph(from html: String) -> (title: String?, description: String?, image: String?) {
        let ogTitle = extractMetaProperty(from: html, property: "og:title")
        let ogDescription = extractMetaProperty(from: html, property: "og:description")
        let ogImage = extractMetaProperty(from: html, property: "og:image")
        return (ogTitle, ogDescription, ogImage)
    }

    // MARK: - Headings

    public static func extractHeadings(from html: String) -> [HeadingInfo] {
        var headings: [HeadingInfo] = []
        let pattern = #"<h([1-6])\b[^>]*>(.*?)</h\1>"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        } catch {
            return headings
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let levelStr = nsHTML.substring(with: match.range(at: 1))
            guard let level = Int(levelStr) else { continue }
            let innerHTML = nsHTML.substring(with: match.range(at: 2))
            let text = stripHTMLTags(innerHTML)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                headings.append(HeadingInfo(level: level, text: text))
            }
        }
        return headings
    }

    // MARK: - Links

    public static func extractLinks(from html: String, baseURL: URL?) -> [LinkInfo] {
        var links: [LinkInfo] = []
        let pattern = #"<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a>"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        } catch {
            return links
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let rawHref = nsHTML.substring(with: match.range(at: 1))
            let innerHTML = nsHTML.substring(with: match.range(at: 2))
            let text = stripHTMLTags(innerHTML).trimmingCharacters(in: .whitespacesAndNewlines)

            let href: String
            if let base = baseURL, let resolved = URL(string: rawHref, relativeTo: base)?.absoluteString {
                href = resolved
            } else {
                href = rawHref
            }

            let isExternal: Bool
            if let base = baseURL, let linkURL = URL(string: href) {
                isExternal = linkURL.host?.lowercased() != base.host?.lowercased()
            } else {
                isExternal = href.hasPrefix("http://") || href.hasPrefix("https://")
            }

            links.append(LinkInfo(text: text, href: href, isExternal: isExternal))
        }
        return links
    }

    // MARK: - Plain Text

    public static func extractText(from html: String) -> String {
        // Remove script and style blocks first
        var cleaned = html
        cleaned = cleaned.replacingOccurrences(
            of: #"<script\b[^>]*>.*?</script>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"<style\b[^>]*>.*?</style>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        // Strip remaining tags
        cleaned = stripHTMLTags(cleaned)
        // Decode entities
        cleaned = decodeHTMLEntities(cleaned)
        // Collapse whitespace
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Full Metadata

    public static func extractMetadata(from html: String, baseURL: URL?) -> PageMetadata {
        let title = extractTitle(from: html)
        let description = extractMetaDescription(from: html)
        let canonical = extractCanonicalURL(from: html)
        let og = extractOpenGraph(from: html)
        let headings = extractHeadings(from: html)
        let links = extractLinks(from: html, baseURL: baseURL)
        let text = extractText(from: html)

        return PageMetadata(
            title: title,
            description: description,
            canonicalURL: canonical,
            ogTitle: og.title,
            ogDescription: og.description,
            ogImage: og.image,
            headings: headings,
            linkCount: links.count,
            textLength: text.count
        )
    }

    // MARK: - Private Helpers

    private static func extractMetaContent(from html: String, name: String) -> String? {
        // Match <meta name="NAME" content="..."> in either attribute order
        let patterns = [
            #"<meta\s[^>]*name\s*=\s*["']\#(name)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#,
            #"<meta\s[^>]*content\s*=\s*["']([^"']*)["'][^>]*name\s*=\s*["']\#(name)["'][^>]*>"#
        ]
        for (i, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsHTML = html as NSString
            if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHTML.length)) {
                // Content group index differs by pattern
                let groupIndex = (i == 0) ? 1 : 1
                if match.numberOfRanges > groupIndex {
                    let value = nsHTML.substring(with: match.range(at: groupIndex))
                    let decoded = decodeHTMLEntities(value)
                    return decoded.isEmpty ? nil : decoded
                }
            }
        }
        return nil
    }

    private static func extractMetaProperty(from html: String, property: String) -> String? {
        let patterns = [
            #"<meta\s[^>]*property\s*=\s*["']\#(property)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#,
            #"<meta\s[^>]*content\s*=\s*["']([^"']*)["'][^>]*property\s*=\s*["']\#(property)["'][^>]*>"#
        ]
        for (i, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsHTML = html as NSString
            if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHTML.length)) {
                let groupIndex = (i == 0) ? 1 : 1
                if match.numberOfRanges > groupIndex {
                    let value = nsHTML.substring(with: match.range(at: groupIndex))
                    let decoded = decodeHTMLEntities(value)
                    return decoded.isEmpty ? nil : decoded
                }
            }
        }
        return nil
    }

    private static func extractAttribute(named name: String, from tag: String) -> String? {
        let pattern = #"\#(name)\s*=\s*["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: nsTag.length)),
              match.numberOfRanges >= 2 else { return nil }
        let value = nsTag.substring(with: match.range(at: 1))
        return value.isEmpty ? nil : decodeHTMLEntities(value)
    }

    private static func stripHTMLTags(_ string: String) -> String {
        return string.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&#160;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char, options: .caseInsensitive)
        }
        // Decode numeric entities &#NNN;
        if let numericRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let nsResult = result as NSString
            let matches = numericRegex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            for match in matches.reversed() {
                let codeStr = nsResult.substring(with: match.range(at: 1))
                if let code = UInt32(codeStr), let scalar = Unicode.Scalar(code) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
                }
            }
        }
        // Decode hex entities &#xHHHH;
        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let nsResult = result as NSString
            let matches = hexRegex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            for match in matches.reversed() {
                let hexStr = nsResult.substring(with: match.range(at: 1))
                if let code = UInt32(hexStr, radix: 16), let scalar = Unicode.Scalar(code) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
                }
            }
        }
        return result
    }
}

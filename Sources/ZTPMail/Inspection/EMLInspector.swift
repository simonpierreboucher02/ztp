import Foundation

public struct EMLInspector: Sendable {

    // MARK: - Result type

    public struct EMLInfo: Codable, Sendable {
        public let from: String?
        public let to: [String]
        public let cc: [String]
        public let subject: String?
        public let date: String?
        public let contentType: String?
        public let hasAttachments: Bool
        public let attachmentNames: [String]
        public let bodyPreview: String?
        public let bodyLength: Int

        public init(
            from: String?,
            to: [String],
            cc: [String],
            subject: String?,
            date: String?,
            contentType: String?,
            hasAttachments: Bool,
            attachmentNames: [String],
            bodyPreview: String?,
            bodyLength: Int
        ) {
            self.from = from
            self.to = to
            self.cc = cc
            self.subject = subject
            self.date = date
            self.contentType = contentType
            self.hasAttachments = hasAttachments
            self.attachmentNames = attachmentNames
            self.bodyPreview = bodyPreview
            self.bodyLength = bodyLength
        }

        enum CodingKeys: String, CodingKey {
            case from
            case to
            case cc
            case subject
            case date
            case contentType = "content_type"
            case hasAttachments = "has_attachments"
            case attachmentNames = "attachment_names"
            case bodyPreview = "body_preview"
            case bodyLength = "body_length"
        }
    }

    // MARK: - Errors

    public enum InspectorError: Error, Sendable {
        case fileNotFound(String)
        case readFailed(String)
        case invalidFormat(String)
    }

    // MARK: - Public API

    public static func inspect(at path: String) throws -> EMLInfo {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            throw InspectorError.fileNotFound(path)
        }
        guard let data = fm.contents(atPath: path) else {
            throw InspectorError.readFailed(path)
        }
        return try inspect(data: data)
    }

    public static func inspect(data: Data) throws -> EMLInfo {
        guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw InspectorError.invalidFormat("Unable to decode EML data as text")
        }

        // Split into headers and body at the first blank line
        let (headers, bodyContent) = splitHeadersAndBody(content)

        // Parse headers (handling continuation lines)
        let parsedHeaders = parseHeaders(headers)

        let from = parsedHeaders["from"]
        let to = parseAddressList(parsedHeaders["to"])
        let cc = parseAddressList(parsedHeaders["cc"])
        let subject = parsedHeaders["subject"]
        let date = parsedHeaders["date"]
        let contentType = parsedHeaders["content-type"]

        // Determine if multipart
        let boundary = extractBoundary(from: contentType)

        var attachmentNames: [String] = []
        var textBody: String = ""

        if let boundary = boundary {
            // Parse multipart
            let parts = splitMultipartBody(bodyContent, boundary: boundary)
            for part in parts {
                let (partHeaders, partBody) = splitHeadersAndBody(part)
                let partParsedHeaders = parseHeaders(partHeaders)

                let partContentDisposition = partParsedHeaders["content-disposition"] ?? ""
                let partContentType = partParsedHeaders["content-type"] ?? ""
                let partContentTransferEncoding = partParsedHeaders["content-transfer-encoding"] ?? ""

                // Check for attachment
                if let filename = extractFilename(from: partContentDisposition) {
                    attachmentNames.append(filename)
                } else if partContentDisposition.lowercased().contains("attachment") {
                    // Attachment without explicit filename -- try name from content-type
                    if let name = extractNameParam(from: partContentType) {
                        attachmentNames.append(name)
                    } else {
                        attachmentNames.append("unnamed")
                    }
                } else if textBody.isEmpty && partContentType.lowercased().contains("text/plain") {
                    // Extract text/plain body
                    textBody = decodePartBody(partBody, encoding: partContentTransferEncoding)
                } else if textBody.isEmpty && partContentType.isEmpty {
                    // Part with no content-type, treat as text
                    textBody = decodePartBody(partBody, encoding: partContentTransferEncoding)
                }
            }
        } else {
            // Not multipart -- entire body is the content
            let transferEncoding = parsedHeaders["content-transfer-encoding"] ?? ""
            textBody = decodePartBody(bodyContent, encoding: transferEncoding)
        }

        let bodyLength = textBody.count
        let bodyPreview: String?
        if textBody.isEmpty {
            bodyPreview = nil
        } else if textBody.count <= 500 {
            bodyPreview = textBody
        } else {
            bodyPreview = String(textBody.prefix(500))
        }

        return EMLInfo(
            from: from,
            to: to,
            cc: cc,
            subject: subject,
            date: date,
            contentType: contentType,
            hasAttachments: !attachmentNames.isEmpty,
            attachmentNames: attachmentNames,
            bodyPreview: bodyPreview,
            bodyLength: bodyLength
        )
    }

    // MARK: - Header parsing

    /// Split raw EML content into the header block and body block.
    /// Headers end at the first blank line (\r\n\r\n or \n\n).
    private static func splitHeadersAndBody(_ content: String) -> (headers: String, body: String) {
        // Try \r\n\r\n first, then \n\n
        if let range = content.range(of: "\r\n\r\n") {
            let headers = String(content[content.startIndex..<range.lowerBound])
            let body = String(content[range.upperBound...])
            return (headers, body)
        }
        if let range = content.range(of: "\n\n") {
            let headers = String(content[content.startIndex..<range.lowerBound])
            let body = String(content[range.upperBound...])
            return (headers, body)
        }
        // No blank line found -- entire content is headers
        return (content, "")
    }

    /// Parse header lines, handling continuation lines (lines starting with whitespace).
    /// Returns a dictionary keyed by lowercased header name.
    private static func parseHeaders(_ headerBlock: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentKey: String?
        var currentValue: String = ""

        let lines = headerBlock.components(separatedBy: .newlines)

        for line in lines {
            if line.isEmpty {
                continue
            }

            // Continuation line: starts with space or tab
            if let first = line.first, (first == " " || first == "\t") {
                if currentKey != nil {
                    // Append to current header value (unfold)
                    currentValue += " " + line.trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            // Save previous header if any
            if let key = currentKey {
                result[key] = currentValue
            }

            // Parse new header: Key: Value
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex])
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                let value = String(line[line.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                currentKey = key
                currentValue = value
            } else {
                // Malformed header line -- skip
                currentKey = nil
                currentValue = ""
            }
        }

        // Save last header
        if let key = currentKey {
            result[key] = currentValue
        }

        return result
    }

    // MARK: - Address parsing

    /// Parse a comma-separated list of email addresses.
    private static func parseAddressList(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        return value
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Multipart parsing

    /// Extract the boundary parameter from a Content-Type header value.
    private static func extractBoundary(from contentType: String?) -> String? {
        guard let contentType = contentType,
              contentType.lowercased().contains("multipart/") else {
            return nil
        }

        // Look for boundary="..." or boundary=...
        let lower = contentType.lowercased()
        guard let boundaryRange = lower.range(of: "boundary=") else {
            return nil
        }

        let afterBoundary = String(contentType[boundaryRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)

        if afterBoundary.hasPrefix("\"") {
            // Quoted boundary
            let unquoted = afterBoundary.dropFirst()
            if let endQuote = unquoted.firstIndex(of: "\"") {
                return String(unquoted[unquoted.startIndex..<endQuote])
            }
            return String(unquoted)
        } else {
            // Unquoted boundary -- ends at semicolon, whitespace, or end of string
            let endChars = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ";"))
            let components = afterBoundary.components(separatedBy: endChars)
            return components.first ?? afterBoundary
        }
    }

    /// Split a multipart body into its parts using the given boundary.
    private static func splitMultipartBody(_ body: String, boundary: String) -> [String] {
        let delimiter = "--" + boundary
        let endDelimiter = delimiter + "--"

        var parts: [String] = []
        let segments = body.components(separatedBy: delimiter)

        for (index, segment) in segments.enumerated() {
            // Skip the preamble (before first boundary)
            if index == 0 { continue }

            // Check if this is the closing delimiter
            var trimmed = segment
            if trimmed.hasPrefix("--") {
                // This is the end delimiter portion or after it
                // The segment starts with "--" meaning original was "--boundary--"
                break
            }

            // Remove leading \r\n or \n after boundary line
            if trimmed.hasPrefix("\r\n") {
                trimmed = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("\n") {
                trimmed = String(trimmed.dropFirst(1))
            }

            // Remove trailing newline before next boundary
            if trimmed.hasSuffix("\r\n") {
                trimmed = String(trimmed.dropLast(2))
            } else if trimmed.hasSuffix("\n") {
                trimmed = String(trimmed.dropLast(1))
            }

            // Check for end delimiter within the segment
            if let endRange = trimmed.range(of: endDelimiter) {
                trimmed = String(trimmed[trimmed.startIndex..<endRange.lowerBound])
                if trimmed.hasSuffix("\r\n") {
                    trimmed = String(trimmed.dropLast(2))
                } else if trimmed.hasSuffix("\n") {
                    trimmed = String(trimmed.dropLast(1))
                }
            }

            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
        }

        return parts
    }

    // MARK: - Attachment filename extraction

    /// Extract filename from Content-Disposition header value.
    /// Looks for: filename="...", filename=..., filename*=utf-8''...
    private static func extractFilename(from disposition: String) -> String? {
        guard disposition.lowercased().contains("attachment") ||
              disposition.lowercased().contains("filename") else {
            return nil
        }

        // Only extract filename if this is actually an attachment
        guard disposition.lowercased().contains("attachment") else {
            return nil
        }

        return extractParam(named: "filename", from: disposition)
    }

    /// Extract the `name` parameter from a Content-Type header.
    private static func extractNameParam(from contentType: String) -> String? {
        return extractParam(named: "name", from: contentType)
    }

    /// Generic parameter extraction: looks for param="value" or param=value
    private static func extractParam(named param: String, from header: String) -> String? {
        let lower = header.lowercased()
        let searchKey = param + "="

        guard let keyRange = lower.range(of: searchKey) else {
            return nil
        }

        let afterKey = String(header[keyRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)

        if afterKey.hasPrefix("\"") {
            let unquoted = afterKey.dropFirst()
            if let endQuote = unquoted.firstIndex(of: "\"") {
                return String(unquoted[unquoted.startIndex..<endQuote])
            }
            return String(unquoted)
        } else {
            // Unquoted -- ends at semicolon, whitespace, or end
            let endChars = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ";"))
            let components = afterKey.components(separatedBy: endChars)
            return components.first
        }
    }

    // MARK: - Body decoding

    /// Decode body content based on Content-Transfer-Encoding.
    private static func decodePartBody(_ body: String, encoding: String) -> String {
        let lowerEncoding = encoding.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lowerEncoding {
        case "quoted-printable":
            return QuotedPrintableDecoder.decode(body)
        case "base64":
            // Base64 text bodies: decode and convert to string
            let cleaned = body.components(separatedBy: .whitespacesAndNewlines).joined()
            if let data = Data(base64Encoded: cleaned),
               let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
            return body
        default:
            // 7bit, 8bit, binary, or unspecified -- return as-is
            return body
        }
    }
}

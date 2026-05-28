import Foundation

public enum QuotedPrintable: Sendable {

    /// Encode a string as quoted-printable per RFC 2045.
    ///
    /// - ASCII printable chars (33-126 except `=`) pass through.
    /// - Spaces and tabs pass through unless at end of line.
    /// - `=` is encoded as `=3D`.
    /// - Other bytes are encoded as `=XX` (uppercase hex).
    /// - Lines are soft-wrapped at 76 characters with `=\r\n`.
    public static func encode(_ string: String) -> String {
        let bytes = Array(string.utf8)
        var result: [UInt8] = []
        var lineLength = 0

        func appendByte(_ byte: UInt8) {
            result.append(byte)
            lineLength += 1
        }

        func appendEncoded(_ byte: UInt8) {
            let hex = String(byte, radix: 16, uppercase: true)
            let padded = hex.count == 1 ? "0\(hex)" : hex
            for c in "=\(padded)".utf8 {
                result.append(c)
            }
            lineLength += 3
        }

        func softBreak() {
            for c in "=\r\n".utf8 {
                result.append(c)
            }
            lineLength = 0
        }

        var i = 0
        while i < bytes.count {
            let byte = bytes[i]

            // Handle CRLF or LF as hard line break
            if byte == 0x0D && i + 1 < bytes.count && bytes[i + 1] == 0x0A {
                // Before the line break, check if trailing spaces/tabs need encoding
                // (already handled inline below)
                result.append(0x0D)
                result.append(0x0A)
                lineLength = 0
                i += 2
                continue
            }
            if byte == 0x0A {
                result.append(0x0D)
                result.append(0x0A)
                lineLength = 0
                i += 1
                continue
            }

            // Determine how many characters this encoding will add
            let encodedSize: Int
            if byte == 0x3D { // '='
                encodedSize = 3
            } else if byte == 0x09 || byte == 0x20 { // tab or space
                // Check if this is at the end of a line
                let isEndOfLine = (i + 1 >= bytes.count)
                    || (bytes[i + 1] == 0x0A)
                    || (i + 1 < bytes.count && bytes[i + 1] == 0x0D)
                encodedSize = isEndOfLine ? 3 : 1
            } else if byte >= 33 && byte <= 126 {
                encodedSize = 1
            } else {
                encodedSize = 3
            }

            // Check if we need a soft line break
            // Reserve 1 char for '=' in case we need a soft break on next iteration
            if lineLength + encodedSize > 75 {
                softBreak()
            }

            // Now encode the byte
            if byte == 0x3D { // '='
                appendEncoded(byte)
            } else if byte == 0x09 || byte == 0x20 { // tab or space
                let isEndOfLine = (i + 1 >= bytes.count)
                    || (bytes[i + 1] == 0x0A)
                    || (i + 1 < bytes.count && bytes[i + 1] == 0x0D)
                if isEndOfLine {
                    appendEncoded(byte)
                } else {
                    appendByte(byte)
                }
            } else if byte >= 33 && byte <= 126 {
                appendByte(byte)
            } else {
                appendEncoded(byte)
            }

            i += 1
        }

        return String(bytes: result, encoding: .utf8) ?? ""
    }
}

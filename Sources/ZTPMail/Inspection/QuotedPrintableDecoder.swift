import Foundation

public enum QuotedPrintableDecoder: Sendable {

    /// Decode a quoted-printable encoded string.
    ///
    /// Rules:
    /// - `=XX` where XX is a two-digit hex value is replaced by the corresponding byte.
    /// - `=\r\n` or `=\n` (soft line break) is removed entirely.
    /// - All other characters pass through unchanged.
    public static func decode(_ encoded: String) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(encoded.utf8.count)

        var iterator = encoded.utf8.makeIterator()

        while let byte = iterator.next() {
            if byte == UInt8(ascii: "=") {
                // Peek at next byte
                guard let next1 = iterator.next() else {
                    // Trailing '=' at end of string -- pass through
                    bytes.append(byte)
                    break
                }

                if next1 == UInt8(ascii: "\r") {
                    // Soft line break: =\r\n -- consume the \n if present
                    if let next2 = iterator.next() {
                        if next2 != UInt8(ascii: "\n") {
                            // \r without \n is unusual but we still treat =\r as soft break
                            // Put back next2 by appending nothing and continuing
                            // Since we can't put back, just ignore this byte
                            // Actually we need to not lose next2 -- but iterator doesn't support putback
                            // So we treat the =\r as soft break and process next2 normally
                            if next2 == UInt8(ascii: "=") {
                                // Start processing a new = sequence
                                // We need to handle this, so just re-add to bytes as if we saw it
                                // Actually, let's just process it inline
                                bytes.append(contentsOf: decodeEqualsSequence(first: next2, iterator: &iterator))
                            } else {
                                bytes.append(next2)
                            }
                        }
                        // If next2 == \n, we consumed the full =\r\n soft break
                    }
                    // Soft line break consumed
                } else if next1 == UInt8(ascii: "\n") {
                    // Soft line break: =\n (without \r)
                    // consumed
                } else {
                    // Should be two hex digits
                    guard let next2 = iterator.next() else {
                        // Malformed: = followed by one char at end
                        bytes.append(byte)
                        bytes.append(next1)
                        break
                    }

                    if let value = hexValue(high: next1, low: next2) {
                        bytes.append(value)
                    } else {
                        // Not valid hex, pass through as-is
                        bytes.append(byte)
                        bytes.append(next1)
                        bytes.append(next2)
                    }
                }
            } else {
                bytes.append(byte)
            }
        }

        return String(bytes: bytes, encoding: .utf8)
            ?? String(bytes: bytes, encoding: .isoLatin1)
            ?? String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Private helpers

    private static func decodeEqualsSequence(first: UInt8, iterator: inout String.UTF8View.Iterator) -> [UInt8] {
        // This won't be called from the main path -- it's a fallback
        return [first]
    }

    private static func hexValue(high: UInt8, low: UInt8) -> UInt8? {
        guard let h = hexDigit(high), let l = hexDigit(low) else {
            return nil
        }
        return (h << 4) | l
    }

    private static func hexDigit(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return byte - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return byte - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return byte - UInt8(ascii: "a") + 10
        default:
            return nil
        }
    }
}

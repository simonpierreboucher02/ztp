import Foundation

public enum Base64LineEncoder: Sendable {

    /// Base64-encode data and insert line breaks every `lineLength` characters.
    ///
    /// - Parameters:
    ///   - data: The raw data to encode.
    ///   - lineLength: Maximum characters per line (default 76).
    /// - Returns: A base64-encoded string with CRLF line breaks.
    public static func encode(_ data: Data, lineLength: Int = 76) -> String {
        let base64 = data.base64EncodedString()
        guard lineLength > 0 else { return base64 }

        var result = ""
        result.reserveCapacity(base64.count + (base64.count / lineLength) * 2)

        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: lineLength, limitedBy: base64.endIndex)
                ?? base64.endIndex
            result += base64[index..<end]
            if end < base64.endIndex {
                result += "\r\n"
            }
            index = end
        }

        return result
    }
}

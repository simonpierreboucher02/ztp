import Foundation

public enum HTMLEscaping: Sendable {
    /// Escape HTML special characters: & < > " '
    public static func escape(_ string: String) -> String {
        var result = string
        // Ampersand must be replaced first to avoid double-escaping
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
}

// DocxXMLEscaping.swift
// ZTPDocx – XML character escaping for OpenXML output

import Foundation

/// Escapes special characters for safe inclusion in XML content and attributes.
public enum DocxXMLEscaping: Sendable {

    /// Returns a copy of `string` with XML-special characters replaced by
    /// their entity references: `& < > " '`.
    public static func escape(_ string: String) -> String {
        var result = string
        // Ampersand must be replaced first to avoid double-escaping.
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}

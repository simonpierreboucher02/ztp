// XMLEscaping.swift
// ZTPExcel – XML string escaping for OpenXML output.

import Foundation

/// Escapes special XML characters in a string so it can be safely
/// embedded in XML element content or attribute values.
enum XMLEscaping: Sendable {

    /// Returns a copy of `string` with all XML-special characters
    /// replaced by their corresponding entity references.
    static func escape(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for ch in string {
            switch ch {
            case "&":  result += "&amp;"
            case "<":  result += "&lt;"
            case ">":  result += "&gt;"
            case "\"": result += "&quot;"
            case "'":  result += "&apos;"
            default:   result.append(ch)
            }
        }
        return result
    }
}

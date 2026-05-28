// SharedStrings.swift
// ZTPExcel – Shared string table for OpenXML XLSX output.

import Foundation

/// Manages the shared string table used by Excel to deduplicate string
/// cell values across all worksheets.
struct SharedStringTable: Sendable {

    /// Maps each unique string to its zero-based index.
    private var table: [String: Int] = [:]

    /// Ordered list of strings matching their index positions.
    private var strings: [String] = []

    /// Returns the shared-string index for `string`, creating a new
    /// entry if necessary.
    mutating func index(for string: String) -> Int {
        if let existing = table[string] {
            return existing
        }
        let idx = strings.count
        strings.append(string)
        table[string] = idx
        return idx
    }

    /// The total number of unique strings in the table.
    var count: Int { strings.count }

    /// Generates the `xl/sharedStrings.xml` file content.
    func toXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\""
        xml += " count=\"\(strings.count)\" uniqueCount=\"\(strings.count)\">"

        for s in strings {
            xml += "<si><t>"
            xml += XMLEscaping.escape(s)
            xml += "</t></si>"
        }

        xml += "</sst>"
        return xml
    }
}

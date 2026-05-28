import Foundation

public struct CSVLoader: Sendable {

    public enum CSVError: Error, Sendable {
        case emptyData
        case noHeaderRow
        case fileNotFound(String)
        case readError(String)
    }

    /// Load a CSV file from a filesystem path.
    public static func load(from path: String) throws -> ChartDataSet {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CSVError.fileNotFound(path)
        }
        return try load(from: data)
    }

    /// Load CSV from raw data.
    public static func load(from data: Data) throws -> ChartDataSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVError.readError("Unable to decode data as UTF-8")
        }
        return try parse(content)
    }

    // MARK: - Internal Parsing

    private static func parse(_ content: String) throws -> ChartDataSet {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CSVError.emptyData }

        let delimiter = detectDelimiter(trimmed)
        let lines = splitLines(trimmed)
        guard let headerLine = lines.first else { throw CSVError.noHeaderRow }

        let columns = parseRow(headerLine, delimiter: delimiter)
        guard !columns.isEmpty else { throw CSVError.noHeaderRow }

        var rows: [[ChartValue]] = []
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let fields = parseRow(line, delimiter: delimiter)
            var row: [ChartValue] = []
            for (j, field) in fields.enumerated() {
                if j >= columns.count { break }
                row.append(parseValue(field))
            }
            // Pad with missing if fewer fields than columns
            while row.count < columns.count {
                row.append(.missing)
            }
            rows.append(row)
        }

        return ChartDataSet(columns: columns, rows: rows)
    }

    private static func detectDelimiter(_ content: String) -> Character {
        // Check the first line for common delimiters
        let firstLine: String
        if let newlineIndex = content.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            firstLine = String(content[content.startIndex..<newlineIndex])
        } else {
            firstLine = content
        }

        let commaCount = firstLine.filter { $0 == "," }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count

        if tabCount > 0 && tabCount >= commaCount && tabCount >= semicolonCount {
            return "\t"
        }
        if semicolonCount > 0 && semicolonCount > commaCount {
            return ";"
        }
        return ","
    }

    private static func splitLines(_ content: String) -> [String] {
        // Handle \r\n, \r, or \n line endings
        var lines: [String] = []
        var current = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let ch = content[i]
            if ch == "\"" {
                inQuotes.toggle()
                current.append(ch)
            } else if !inQuotes && (ch == "\n" || ch == "\r") {
                lines.append(current)
                current = ""
                // Handle \r\n
                if ch == "\r" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\n" {
                        i = next
                    }
                }
            } else {
                current.append(ch)
            }
            i = content.index(after: i)
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    private static func parseRow(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        // Escaped quote
                        current.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == delimiter {
                    fields.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private static func parseValue(_ field: String) -> ChartValue {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "null" || trimmed.lowercased() == "na" || trimmed == "-" {
            return .missing
        }
        // Try parsing as a number
        // Remove commas from numbers like "1,000"
        let numberCandidate = trimmed.replacingOccurrences(of: ",", with: "")
        if let d = Double(numberCandidate) {
            return .number(d)
        }
        return .string(trimmed)
    }
}

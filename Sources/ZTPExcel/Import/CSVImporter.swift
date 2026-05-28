// CSVImporter.swift
// ZTPExcel – CSV import into Workbook model.

import Foundation

/// Errors thrown during CSV import.
public enum CSVImportError: Error, Sendable {
    case invalidUTF8
    case emptyData
}

/// Imports CSV data into an in-memory ``Workbook``.
public struct CSVImporter: Sendable {

    // MARK: - Options

    /// Configuration options for CSV import.
    public struct Options: Sendable {
        /// The field delimiter character. When `nil`, auto-detected from the first line.
        public var delimiter: Character?

        /// Whether the first row should be treated as a header.
        public var hasHeader: Bool

        /// Whether to attempt type inference (Int, Double, Bool) on cell values.
        public var inferTypes: Bool

        /// The name for the generated worksheet.
        public var sheetName: String

        public init(
            delimiter: Character? = nil,
            hasHeader: Bool = true,
            inferTypes: Bool = false,
            sheetName: String = "Sheet1"
        ) {
            self.delimiter = delimiter
            self.hasHeader = hasHeader
            self.inferTypes = inferTypes
            self.sheetName = sheetName
        }
    }

    // MARK: - Public API

    /// Imports CSV from raw `Data` (UTF-8).
    ///
    /// - Parameters:
    ///   - data: The raw CSV bytes.
    ///   - options: Import configuration.
    /// - Returns: A ``Workbook`` containing one worksheet with all parsed cells.
    public static func importCSV(from data: Data, options: Options = Options()) throws -> Workbook {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidUTF8
        }
        guard !text.isEmpty else {
            throw CSVImportError.emptyData
        }

        let delimiter = options.delimiter ?? autoDetectDelimiter(in: text)
        let rows = parseCSV(text: text, delimiter: delimiter)

        guard !rows.isEmpty else {
            throw CSVImportError.emptyData
        }

        var cells: [Cell] = []

        for (rowIndex, row) in rows.enumerated() {
            let excelRow = rowIndex + 1
            for (colIndex, field) in row.enumerated() {
                let excelCol = colIndex + 1

                // Safety: skip cells that exceed Excel limits
                guard excelCol <= CellAddress.maxColumn,
                      excelRow <= CellAddress.maxRow else { continue }

                let value: CellValue
                if options.inferTypes {
                    value = inferType(from: field)
                } else {
                    value = field.isEmpty ? .blank : .string(field)
                }

                let address = CellAddress(column: excelCol, row: excelRow)
                cells.append(Cell(address: address, value: value))
            }
        }

        let sheet = Worksheet(name: options.sheetName, cells: cells)
        return Workbook(sheets: [sheet])
    }

    /// Imports CSV from a file path.
    ///
    /// - Parameters:
    ///   - path: The file system path to the CSV file.
    ///   - options: Import configuration.
    /// - Returns: A ``Workbook`` containing one worksheet with all parsed cells.
    public static func importCSV(at path: String, options: Options = Options()) throws -> Workbook {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try importCSV(from: data, options: options)
    }

    // MARK: - Delimiter detection

    /// Inspects the first line and picks the most frequent delimiter candidate.
    private static func autoDetectDelimiter(in text: String) -> Character {
        let candidates: [Character] = [",", ";", "\t"]

        // Take the first line (before any newline).
        let firstLine: Substring
        if let newlineIndex = text.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            firstLine = text[text.startIndex..<newlineIndex]
        } else {
            firstLine = text[...]
        }

        var bestCandidate: Character = ","
        var bestCount = 0

        for candidate in candidates {
            let count = firstLine.filter { $0 == candidate }.count
            if count > bestCount {
                bestCount = count
                bestCandidate = candidate
            }
        }

        return bestCandidate
    }

    // MARK: - RFC 4180 parser

    /// Parses CSV text into a 2D array of strings, handling quoted fields.
    private static func parseCSV(text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]

            if inQuotes {
                if ch == "\"" {
                    // Peek ahead for escaped quote
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" {
                        // Escaped double quote
                        currentField.append("\"")
                        i = text.index(after: next)
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i = text.index(after: i)
                        continue
                    }
                } else {
                    currentField.append(ch)
                    i = text.index(after: i)
                    continue
                }
            }

            // Not in quotes
            if ch == "\"" {
                inQuotes = true
                i = text.index(after: i)
                continue
            }

            if ch == delimiter {
                currentRow.append(currentField)
                currentField = ""
                i = text.index(after: i)
                continue
            }

            if ch == "\r" {
                // Handle \r\n or standalone \r
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.isEmpty || rows.count > 0 {
                    rows.append(currentRow)
                }
                currentRow = []

                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "\n" {
                    i = text.index(after: next)
                } else {
                    i = text.index(after: i)
                }
                continue
            }

            if ch == "\n" {
                currentRow.append(currentField)
                currentField = ""
                rows.append(currentRow)
                currentRow = []
                i = text.index(after: i)
                continue
            }

            currentField.append(ch)
            i = text.index(after: i)
        }

        // Flush remaining field / row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Type inference

    /// Attempts to infer a typed ``CellValue`` from a raw string field.
    ///
    /// Order: Int -> Double -> Bool -> String (blank if empty).
    private static func inferType(from field: String) -> CellValue {
        let trimmed = field.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .blank
        }

        // Try Int
        if let intVal = Int(trimmed) {
            return .integer(intVal)
        }

        // Try Double
        if let doubleVal = Double(trimmed) {
            return .number(doubleVal)
        }

        // Try Bool
        let lower = trimmed.lowercased()
        if lower == "true" {
            return .boolean(true)
        }
        if lower == "false" {
            return .boolean(false)
        }

        return .string(field)
    }
}

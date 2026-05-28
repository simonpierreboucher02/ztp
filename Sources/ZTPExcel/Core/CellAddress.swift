// CellAddress.swift
// ZTPExcel – Cell address model (e.g. "A1", "XFD1048576")

import Foundation

/// A validated cell address within an Excel worksheet.
///
/// Columns are 1-based (1 = A, 16384 = XFD).
/// Rows are 1-based (1 … 1_048_576).
public struct CellAddress: Codable, Sendable, Equatable, Hashable {

    // MARK: - Limits

    public static let maxColumn = 16_384    // XFD
    public static let maxRow    = 1_048_576

    // MARK: - Stored properties

    /// 1-based column index.
    public let column: Int

    /// 1-based row index.
    public let row: Int

    // MARK: - Initialisers

    /// Creates a cell address from numeric column and row values.
    ///
    /// - Parameters:
    ///   - column: 1-based column number (1 … 16 384).
    ///   - row:    1-based row number    (1 … 1 048 576).
    /// - Precondition: Both values must be within the valid Excel range.
    public init(column: Int, row: Int) {
        precondition(
            column >= 1 && column <= Self.maxColumn,
            "Column \(column) is out of range 1...\(Self.maxColumn)"
        )
        precondition(
            row >= 1 && row <= Self.maxRow,
            "Row \(row) is out of range 1...\(Self.maxRow)"
        )
        self.column = column
        self.row = row
    }

    /// Failable initialiser that parses an A1-style reference string
    /// such as `"A1"`, `"B2"`, `"AA10"`, or `"XFD1048576"`.
    public init?(string ref: String) {
        let uppercased = ref.uppercased()

        // Split into letter prefix and digit suffix.
        var letterPart = ""
        var digitPart  = ""
        var seenDigit  = false

        for ch in uppercased {
            if ch.isLetter && !seenDigit {
                letterPart.append(ch)
            } else if ch.isWholeNumber {
                seenDigit = true
                digitPart.append(ch)
            } else {
                return nil // invalid character or letters after digits
            }
        }

        guard !letterPart.isEmpty, !digitPart.isEmpty else { return nil }
        guard let row = Int(digitPart), row >= 1, row <= Self.maxRow else { return nil }

        let col = Self.columnNumber(from: letterPart)
        guard col >= 1 && col <= Self.maxColumn else { return nil }

        self.column = col
        self.row = row
    }

    // MARK: - Computed properties

    /// The A1-style reference string for this address (e.g. `"B7"`).
    public var reference: String {
        Self.columnLetters(from: column) + String(row)
    }

    // MARK: - Column ↔ Letters helpers

    /// Converts a 1-based column number to its Excel letter representation.
    ///
    /// - Example: 1 → "A", 27 → "AA", 16384 → "XFD"
    public static func columnLetters(from number: Int) -> String {
        var result = ""
        var n = number
        while n > 0 {
            n -= 1 // shift to 0-based
            let remainder = n % 26
            result = String(UnicodeScalar(65 + remainder)!) + result
            n /= 26
        }
        return result
    }

    /// Converts an Excel column letter string to a 1-based column number.
    ///
    /// - Example: "A" → 1, "AA" → 27, "XFD" → 16384
    /// - Returns: 0 if the input is empty or contains non-letter characters.
    public static func columnNumber(from letters: String) -> Int {
        let upper = letters.uppercased()
        var result = 0
        for ch in upper {
            guard let value = ch.asciiValue, value >= 65, value <= 90 else { return 0 }
            result = result * 26 + Int(value - 64)
        }
        return result
    }
}

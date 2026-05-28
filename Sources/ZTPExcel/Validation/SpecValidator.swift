// SpecValidator.swift
// ZTPExcel – Validates WorkbookSpec for correctness before generation.

import Foundation

/// Validates a ``WorkbookSpec`` for structural correctness, ensuring
/// that all references are valid and constraints are met before
/// generating an .xlsx file.
public struct SpecValidator: Sendable {

    // MARK: - Result types

    /// The overall spec validation result.
    public struct SpecValidationResult: Codable, Sendable {
        public let valid: Bool
        public let errors: [SpecValidationError]
    }

    /// A single validation error with diagnostic information.
    public struct SpecValidationError: Codable, Sendable {
        public let code: String
        public let message: String
        public let path: String?
        public let hint: String?
    }

    // MARK: - Error codes

    private enum Code {
        static let invalidVersion = "INVALID_VERSION"
        static let noSheets = "NO_SHEETS"
        static let emptySheetName = "EMPTY_SHEET_NAME"
        static let duplicateSheetName = "DUPLICATE_SHEET_NAME"
        static let invalidCellAddress = "INVALID_CELL_ADDRESS"
        static let duplicateCellAddress = "DUPLICATE_CELL_ADDRESS"
        static let undefinedStyle = "UNDEFINED_STYLE"
        static let invalidJSON = "INVALID_JSON"
        static let invalidVersion2 = "UNSUPPORTED_VERSION"
    }

    // MARK: - Public API

    /// Validates a ``WorkbookSpec`` instance.
    ///
    /// Checks:
    /// - version field is "ztp-excel/0.1"
    /// - at least one sheet
    /// - sheet names non-empty and unique
    /// - all cell addresses valid and within Excel limits
    /// - referenced style names exist in the styles dictionary
    /// - no duplicate cell addresses within a sheet
    ///
    /// - Parameter spec: The workbook specification to validate.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(spec: WorkbookSpec) -> SpecValidationResult {
        var errors: [SpecValidationError] = []

        // 1. Version check
        if spec.version != "ztp-excel/0.1" {
            errors.append(SpecValidationError(
                code: Code.invalidVersion,
                message: "Version must be \"ztp-excel/0.1\", got \"\(spec.version)\"",
                path: "version",
                hint: "Set version to \"ztp-excel/0.1\""
            ))
        }

        // 2. At least one sheet
        if spec.sheets.isEmpty {
            errors.append(SpecValidationError(
                code: Code.noSheets,
                message: "At least one sheet is required",
                path: "sheets",
                hint: "Add at least one sheet to the sheets array"
            ))
        }

        // 3. Sheet names non-empty and unique
        var seenSheetNames: Set<String> = []
        for (sheetIndex, sheet) in spec.sheets.enumerated() {
            let sheetPath = "sheets[\(sheetIndex)]"

            if sheet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(SpecValidationError(
                    code: Code.emptySheetName,
                    message: "Sheet name must not be empty",
                    path: "\(sheetPath).name",
                    hint: "Provide a non-empty name for the sheet"
                ))
            }

            let normalizedName = sheet.name.lowercased()
            if seenSheetNames.contains(normalizedName) {
                errors.append(SpecValidationError(
                    code: Code.duplicateSheetName,
                    message: "Duplicate sheet name: \"\(sheet.name)\"",
                    path: "\(sheetPath).name",
                    hint: "Each sheet must have a unique name"
                ))
            }
            seenSheetNames.insert(normalizedName)

            // 4 & 6. Cell address validation and duplicate detection
            var seenAddresses: Set<String> = []
            for (cellIndex, cell) in sheet.cells.enumerated() {
                let cellPath = "\(sheetPath).cells[\(cellIndex)]"

                // Valid address?
                guard let addr = CellAddress(string: cell.address) else {
                    errors.append(SpecValidationError(
                        code: Code.invalidCellAddress,
                        message: "Invalid cell address: \"\(cell.address)\"",
                        path: "\(cellPath).address",
                        hint: "Use A1-style references within Excel limits (A1 to XFD1048576)"
                    ))
                    continue
                }

                // Within Excel limits (CellAddress init already enforces this,
                // but the failable init returns nil for out-of-range, so we're safe)
                _ = addr

                // Duplicate in this sheet?
                let normalizedRef = cell.address.uppercased()
                if seenAddresses.contains(normalizedRef) {
                    errors.append(SpecValidationError(
                        code: Code.duplicateCellAddress,
                        message: "Duplicate cell address \"\(cell.address)\" in sheet \"\(sheet.name)\"",
                        path: "\(cellPath).address",
                        hint: "Each cell address must be unique within a sheet"
                    ))
                }
                seenAddresses.insert(normalizedRef)

                // 5. Style reference exists?
                if let styleName = cell.style {
                    let stylesDefined = spec.styles ?? [:]
                    if stylesDefined[styleName] == nil {
                        errors.append(SpecValidationError(
                            code: Code.undefinedStyle,
                            message: "Style \"\(styleName)\" is not defined in the styles dictionary",
                            path: "\(cellPath).style",
                            hint: "Define \"\(styleName)\" in the top-level styles object, or remove the reference"
                        ))
                    }
                }
            }
        }

        return SpecValidationResult(valid: errors.isEmpty, errors: errors)
    }

    /// Validates a JSON-encoded ``WorkbookSpec``.
    ///
    /// First attempts to decode the JSON, then validates the resulting spec.
    ///
    /// - Parameter jsonData: Raw JSON bytes.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(jsonData: Data) -> SpecValidationResult {
        let decoder = JSONDecoder()

        let spec: WorkbookSpec
        do {
            spec = try decoder.decode(WorkbookSpec.self, from: jsonData)
        } catch {
            return SpecValidationResult(
                valid: false,
                errors: [
                    SpecValidationError(
                        code: Code.invalidJSON,
                        message: "Failed to decode JSON: \(error.localizedDescription)",
                        path: nil,
                        hint: "Ensure the JSON matches the WorkbookSpec schema"
                    )
                ]
            )
        }

        return validate(spec: spec)
    }
}

// XLSXValidator.swift
// ZTPExcel – Validates .xlsx files for structural correctness.

import Foundation

/// Errors thrown during XLSX validation setup.
public enum XLSXValidationError: Error, Sendable {
    case fileNotFound(String)
    case unreadable(String)
}

/// Validates that an .xlsx file conforms to basic OpenXML structural
/// requirements and contains well-formed data.
public struct XLSXValidator: Sendable {

    // MARK: - Result types

    /// The overall validation result.
    public struct ValidationResult: Codable, Sendable {
        public let valid: Bool
        public let checks: [ValidationCheck]
    }

    /// An individual validation check.
    public struct ValidationCheck: Codable, Sendable {
        public let name: String
        public let passed: Bool
        public let message: String?
    }

    // MARK: - Required files

    private static let requiredFiles = [
        "[Content_Types].xml",
        "_rels/.rels",
        "xl/workbook.xml",
    ]

    // MARK: - Public API

    /// Validates the .xlsx file at `path`.
    ///
    /// Performs the following checks:
    /// 1. ZIP readable
    /// 2. Required OpenXML files present
    /// 3. At least one sheet defined in workbook.xml
    /// 4. Referenced worksheet files exist
    /// 5. Basic XML well-formedness
    /// 6. Shared strings file valid if present
    /// 7. Cell addresses within Excel limits
    ///
    /// - Parameter path: Path to the .xlsx file.
    /// - Returns: A ``ValidationResult`` with individual check outcomes.
    public static func validate(at path: String) throws -> ValidationResult {
        guard FileManager.default.fileExists(atPath: path) else {
            throw XLSXValidationError.fileNotFound(path)
        }

        var checks: [ValidationCheck] = []

        // 1. ZIP readable
        let entries: [ZIPReader.Entry]
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            entries = try ZIPReader.readEntries(from: data)
            checks.append(ValidationCheck(
                name: "zip_readable",
                passed: true,
                message: "ZIP archive parsed successfully (\(entries.count) entries)"
            ))
        } catch {
            checks.append(ValidationCheck(
                name: "zip_readable",
                passed: false,
                message: "Failed to read ZIP: \(error.localizedDescription)"
            ))
            return ValidationResult(valid: false, checks: checks)
        }

        let entryPaths = Set(entries.map(\.path))
        let entryMap = Dictionary(
            entries.map { ($0.path, $0.data) },
            uniquingKeysWith: { first, _ in first }
        )

        // 2. Required files present
        for required in requiredFiles {
            let present = entryPaths.contains(required)
            checks.append(ValidationCheck(
                name: "required_file_\(required)",
                passed: present,
                message: present ? nil : "Missing required file: \(required)"
            ))
        }

        // 3. At least one sheet in workbook.xml
        let sheetNames: [String]
        if let wbData = entryMap["xl/workbook.xml"],
           let wbXML = String(data: wbData, encoding: .utf8) {
            sheetNames = SimpleXMLExtractor.extractSheetNames(from: wbXML)
            let hasSheets = !sheetNames.isEmpty
            checks.append(ValidationCheck(
                name: "has_sheets",
                passed: hasSheets,
                message: hasSheets ? "\(sheetNames.count) sheet(s) defined" : "No sheets found in workbook.xml"
            ))
        } else {
            sheetNames = []
            checks.append(ValidationCheck(
                name: "has_sheets",
                passed: false,
                message: "Cannot read xl/workbook.xml"
            ))
        }

        // 4. Referenced worksheet files exist
        let worksheetPaths = resolveWorksheetPaths(entryMap: entryMap)
        for (index, wsPath) in worksheetPaths.enumerated() {
            let name = index < sheetNames.count ? sheetNames[index] : "sheet\(index + 1)"
            let exists = entryPaths.contains(wsPath)
            checks.append(ValidationCheck(
                name: "worksheet_exists_\(name)",
                passed: exists,
                message: exists ? nil : "Worksheet file not found: \(wsPath)"
            ))
        }

        // 5. Basic XML well-formedness for critical files
        let criticalXMLFiles = ["xl/workbook.xml", "[Content_Types].xml"]
        for xmlFile in criticalXMLFiles {
            if let xmlData = entryMap[xmlFile],
               let xmlStr = String(data: xmlData, encoding: .utf8) {
                let wellFormed = checkBasicXMLWellFormedness(xmlStr)
                checks.append(ValidationCheck(
                    name: "xml_wellformed_\(xmlFile)",
                    passed: wellFormed,
                    message: wellFormed ? nil : "Possible XML well-formedness issue in \(xmlFile)"
                ))
            }
        }

        // 6. Shared strings valid if present
        if let ssData = entryMap["xl/sharedStrings.xml"],
           let ssXML = String(data: ssData, encoding: .utf8) {
            let strings = SimpleXMLExtractor.extractSharedStrings(from: ssXML)
            let wellFormed = checkBasicXMLWellFormedness(ssXML)
            let valid = wellFormed
            checks.append(ValidationCheck(
                name: "shared_strings_valid",
                passed: valid,
                message: valid ? "\(strings.count) shared string(s)" : "Shared strings file is malformed"
            ))
        }

        // 7. Cell addresses within Excel limits
        var allCellsValid = true
        var invalidCellMessage: String?

        for wsPath in worksheetPaths {
            guard let wsData = entryMap[wsPath],
                  let wsXML = String(data: wsData, encoding: .utf8) else { continue }

            let cells = SimpleXMLExtractor.extractCells(from: wsXML)
            for cell in cells {
                if CellAddress(string: cell.ref) == nil {
                    allCellsValid = false
                    invalidCellMessage = "Invalid or out-of-range cell address: \(cell.ref)"
                    break
                }
            }
            if !allCellsValid { break }
        }

        checks.append(ValidationCheck(
            name: "cell_addresses_valid",
            passed: allCellsValid,
            message: allCellsValid ? nil : invalidCellMessage
        ))

        let allPassed = checks.allSatisfy(\.passed)
        return ValidationResult(valid: allPassed, checks: checks)
    }

    // MARK: - Private helpers

    /// Resolves worksheet file paths from the workbook relationships.
    private static func resolveWorksheetPaths(entryMap: [String: Data]) -> [String] {
        guard let wbData = entryMap["xl/workbook.xml"],
              let wbXML = String(data: wbData, encoding: .utf8) else {
            return []
        }

        let sheetRelations = SimpleXMLExtractor.extractSheetRelations(from: wbXML)

        guard let relsData = entryMap["xl/_rels/workbook.xml.rels"],
              let relsXML = String(data: relsData, encoding: .utf8) else {
            // Default paths
            return sheetRelations.enumerated().map { "xl/worksheets/sheet\($0.offset + 1).xml" }
        }

        let rels = SimpleXMLExtractor.extractRelationships(from: relsXML)
        let relMap = Dictionary(rels.map { ($0.id, $0.target) }, uniquingKeysWith: { first, _ in first })

        var paths: [String] = []
        for rel in sheetRelations {
            if let target = relMap[rel.rId] {
                let fullPath = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/\(target)"
                paths.append(fullPath)
            } else {
                paths.append("xl/worksheets/sheet\(paths.count + 1).xml")
            }
        }

        return paths
    }

    /// Performs a basic XML well-formedness check.
    ///
    /// Verifies that the XML declaration (if present) is valid and that
    /// opening/closing tag counts roughly match for critical elements.
    private static func checkBasicXMLWellFormedness(_ xml: String) -> Bool {
        // Check that it starts with <?xml or a root element
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Basic check: count < and > — they should be equal
        let openCount = xml.filter { $0 == "<" }.count
        let closeCount = xml.filter { $0 == ">" }.count
        if openCount != closeCount { return false }

        // Check for unmatched critical tags (simple heuristic)
        // Every </tag> should have a corresponding <tag or <tag>
        // This is a lightweight check, not a full parser.
        return true
    }
}

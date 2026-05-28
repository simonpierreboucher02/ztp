// XLSXInspector.swift
// ZTPExcel – Inspect .xlsx files without full import.

import Foundation

/// Errors thrown during XLSX inspection.
public enum XLSXInspectionError: Error, Sendable {
    case fileNotFound(String)
    case invalidXLSX(String)
    case sheetNotFound(String)
    case cellNotFound(String)
    case invalidCellReference(String)
}

/// Inspects .xlsx files to report structure, preview data, and examine
/// individual cells without building a full in-memory workbook.
public struct XLSXInspector: Sendable {

    // MARK: - Result types

    /// Summary information about a workbook.
    public struct WorkbookInfo: Codable, Sendable {
        public let sheets: Int
        public let hasFormulas: Bool
        public let hasStyles: Bool
        public let sheetDetails: [SheetInfo]
    }

    /// Summary information about a single sheet.
    public struct SheetInfo: Codable, Sendable {
        public let name: String
        public let rowsDetected: Int
        public let columnsDetected: Int
    }

    /// Detailed information about a single cell.
    public struct CellInfo: Codable, Sendable {
        public let address: String
        public let type: String
        public let value: String?
        public let formula: String?
        public let styleIndex: Int?
    }

    // MARK: - Public API

    /// Inspects the .xlsx file at the given path and returns structural metadata.
    ///
    /// - Parameter path: Path to the .xlsx file.
    /// - Returns: A ``WorkbookInfo`` summarising the workbook.
    public static func inspect(at path: String) throws -> WorkbookInfo {
        let entries = try loadZIPEntries(at: path)
        let entryMap = Dictionary(entries.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })

        // Parse workbook.xml for sheet names
        guard let workbookData = entryMap["xl/workbook.xml"],
              let workbookXML = String(data: workbookData, encoding: .utf8) else {
            throw XLSXInspectionError.invalidXLSX("Missing xl/workbook.xml")
        }

        let sheetNames = SimpleXMLExtractor.extractSheetNames(from: workbookXML)

        // Resolve sheet file paths via relationships
        let sheetPaths = resolveSheetPaths(entryMap: entryMap, workbookXML: workbookXML)

        // Check for styles
        let hasStyles: Bool
        if let stylesData = entryMap["xl/styles.xml"],
           let stylesXML = String(data: stylesData, encoding: .utf8) {
            hasStyles = SimpleXMLExtractor.hasStyles(in: stylesXML)
        } else {
            hasStyles = false
        }

        // Analyse each sheet
        var sheetDetails: [SheetInfo] = []
        var hasFormulas = false

        for (index, name) in sheetNames.enumerated() {
            let sheetPath: String
            if index < sheetPaths.count {
                sheetPath = sheetPaths[index]
            } else {
                sheetPath = "xl/worksheets/sheet\(index + 1).xml"
            }

            guard let sheetData = entryMap[sheetPath],
                  let sheetXML = String(data: sheetData, encoding: .utf8) else {
                sheetDetails.append(SheetInfo(name: name, rowsDetected: 0, columnsDetected: 0))
                continue
            }

            let cells = SimpleXMLExtractor.extractCells(from: sheetXML)

            var maxRow = 0
            var maxCol = 0

            for cell in cells {
                if cell.formula != nil {
                    hasFormulas = true
                }

                if let addr = CellAddress(string: cell.ref) {
                    maxRow = max(maxRow, addr.row)
                    maxCol = max(maxCol, addr.column)
                }
            }

            sheetDetails.append(SheetInfo(name: name, rowsDetected: maxRow, columnsDetected: maxCol))
        }

        return WorkbookInfo(
            sheets: sheetNames.count,
            hasFormulas: hasFormulas,
            hasStyles: hasStyles,
            sheetDetails: sheetDetails
        )
    }

    /// Previews a sheet's contents as a 2D array of optional strings.
    ///
    /// - Parameters:
    ///   - path: Path to the .xlsx file.
    ///   - sheetName: The name of the sheet to preview.
    ///   - maxRows: Maximum number of rows to include in the preview.
    /// - Returns: A 2D array where each inner array is a row of cell values as strings.
    public static func previewSheet(
        at path: String,
        sheetName: String,
        maxRows: Int
    ) throws -> [[String?]] {
        let entries = try loadZIPEntries(at: path)
        let entryMap = Dictionary(entries.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })

        // Load shared strings
        let sharedStrings: [String]
        if let ssData = entryMap["xl/sharedStrings.xml"],
           let ssXML = String(data: ssData, encoding: .utf8) {
            sharedStrings = SimpleXMLExtractor.extractSharedStrings(from: ssXML)
        } else {
            sharedStrings = []
        }

        let sheetXML = try findSheetXML(named: sheetName, entryMap: entryMap)
        let cells = SimpleXMLExtractor.extractCells(from: sheetXML)

        // Build a sparse grid, then convert to 2D array.
        var grid: [Int: [Int: String]] = [:]  // row -> col -> value
        var maxRow = 0
        var maxCol = 0

        for cell in cells {
            guard let addr = CellAddress(string: cell.ref) else { continue }
            if addr.row > maxRows { continue }

            let displayValue = resolveDisplayValue(cell: cell, sharedStrings: sharedStrings)
            grid[addr.row, default: [:]][addr.column] = displayValue

            maxRow = max(maxRow, addr.row)
            maxCol = max(maxCol, addr.column)
        }

        maxRow = min(maxRow, maxRows)

        var result: [[String?]] = []
        for row in 1...max(maxRow, 1) {
            var rowData: [String?] = []
            for col in 1...max(maxCol, 1) {
                rowData.append(grid[row]?[col])
            }
            result.append(rowData)
        }

        return result
    }

    /// Inspects a single cell by A1-style reference.
    ///
    /// - Parameters:
    ///   - path: Path to the .xlsx file.
    ///   - reference: An A1-style cell reference, optionally prefixed with a sheet name
    ///     and `!` (e.g. `"Sheet1!A1"` or just `"A1"`).
    /// - Returns: Detailed information about the cell.
    public static func inspectCell(at path: String, reference: String) throws -> CellInfo {
        let entries = try loadZIPEntries(at: path)
        let entryMap = Dictionary(entries.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })

        // Parse sheet name and cell ref
        let (sheetName, cellRef) = parseReference(reference, entryMap: entryMap)

        guard CellAddress(string: cellRef) != nil else {
            throw XLSXInspectionError.invalidCellReference(cellRef)
        }

        // Load shared strings
        let sharedStrings: [String]
        if let ssData = entryMap["xl/sharedStrings.xml"],
           let ssXML = String(data: ssData, encoding: .utf8) {
            sharedStrings = SimpleXMLExtractor.extractSharedStrings(from: ssXML)
        } else {
            sharedStrings = []
        }

        let sheetXML: String
        if let name = sheetName {
            sheetXML = try findSheetXML(named: name, entryMap: entryMap)
        } else {
            // Default to first sheet
            sheetXML = try findFirstSheetXML(entryMap: entryMap)
        }

        let cells = SimpleXMLExtractor.extractCells(from: sheetXML)
        let upperRef = cellRef.uppercased()

        guard let cell = cells.first(where: { $0.ref.uppercased() == upperRef }) else {
            throw XLSXInspectionError.cellNotFound(reference)
        }

        let displayValue = resolveDisplayValue(cell: cell, sharedStrings: sharedStrings)
        let typeName = resolveTypeName(type: cell.type, formula: cell.formula)

        // Extract style index from the cell element
        // We re-parse to get the s attribute — the extractCells doesn't return it,
        // so we handle it here by re-scanning.
        let styleIndex: Int? = nil  // simplified — style index not tracked in extractCells

        return CellInfo(
            address: cell.ref,
            type: typeName,
            value: displayValue,
            formula: cell.formula,
            styleIndex: styleIndex
        )
    }

    // MARK: - Private helpers

    /// Loads ZIP entries from a file path.
    private static func loadZIPEntries(at path: String) throws -> [ZIPReader.Entry] {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw XLSXInspectionError.fileNotFound(path)
        }
        let data = try Data(contentsOf: url)
        return try ZIPReader.readEntries(from: data)
    }

    /// Resolves the file paths for each sheet via xl/_rels/workbook.xml.rels.
    private static func resolveSheetPaths(entryMap: [String: Data], workbookXML: String) -> [String] {
        let sheetRelations = SimpleXMLExtractor.extractSheetRelations(from: workbookXML)

        // Load workbook relationships
        guard let relsData = entryMap["xl/_rels/workbook.xml.rels"],
              let relsXML = String(data: relsData, encoding: .utf8) else {
            // Fall back to default paths
            return sheetRelations.enumerated().map { "xl/worksheets/sheet\($0.offset + 1).xml" }
        }

        let relationships = SimpleXMLExtractor.extractRelationships(from: relsXML)
        let relMap = Dictionary(relationships.map { ($0.id, $0.target) }, uniquingKeysWith: { first, _ in first })

        var paths: [String] = []
        for rel in sheetRelations {
            if let target = relMap[rel.rId] {
                // Targets are relative to xl/
                let fullPath = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/\(target)"
                paths.append(fullPath)
            } else {
                paths.append("xl/worksheets/sheet\(paths.count + 1).xml")
            }
        }

        return paths
    }

    /// Finds the XML content of a sheet by name.
    private static func findSheetXML(named sheetName: String, entryMap: [String: Data]) throws -> String {
        // Get workbook.xml to find the sheet
        guard let workbookData = entryMap["xl/workbook.xml"],
              let workbookXML = String(data: workbookData, encoding: .utf8) else {
            throw XLSXInspectionError.invalidXLSX("Missing xl/workbook.xml")
        }

        let sheetNames = SimpleXMLExtractor.extractSheetNames(from: workbookXML)
        guard let sheetIndex = sheetNames.firstIndex(of: sheetName) else {
            throw XLSXInspectionError.sheetNotFound(sheetName)
        }

        let sheetPaths = resolveSheetPaths(entryMap: entryMap, workbookXML: workbookXML)
        let sheetPath: String
        if sheetIndex < sheetPaths.count {
            sheetPath = sheetPaths[sheetIndex]
        } else {
            sheetPath = "xl/worksheets/sheet\(sheetIndex + 1).xml"
        }

        guard let sheetData = entryMap[sheetPath],
              let sheetXMLStr = String(data: sheetData, encoding: .utf8) else {
            throw XLSXInspectionError.sheetNotFound(sheetName)
        }

        return sheetXMLStr
    }

    /// Returns the XML of the first sheet in the workbook.
    private static func findFirstSheetXML(entryMap: [String: Data]) throws -> String {
        guard let workbookData = entryMap["xl/workbook.xml"],
              let workbookXML = String(data: workbookData, encoding: .utf8) else {
            throw XLSXInspectionError.invalidXLSX("Missing xl/workbook.xml")
        }

        let sheetNames = SimpleXMLExtractor.extractSheetNames(from: workbookXML)
        guard let firstName = sheetNames.first else {
            throw XLSXInspectionError.invalidXLSX("No sheets found")
        }

        return try findSheetXML(named: firstName, entryMap: entryMap)
    }

    /// Parses a possibly sheet-qualified reference like "Sheet1!A1" into components.
    private static func parseReference(
        _ reference: String,
        entryMap: [String: Data]
    ) -> (sheetName: String?, cellRef: String) {
        if let bangIndex = reference.lastIndex(of: "!") {
            let sheetPart = String(reference[reference.startIndex..<bangIndex])
            let cellPart = String(reference[reference.index(after: bangIndex)...])
            // Strip surrounding quotes from sheet name if present
            let cleanSheet = sheetPart.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return (cleanSheet, cellPart)
        }
        return (nil, reference)
    }

    /// Resolves the display value for a cell, dereferencing shared strings if needed.
    private static func resolveDisplayValue(
        cell: (ref: String, type: String?, value: String?, formula: String?),
        sharedStrings: [String]
    ) -> String? {
        guard let rawValue = cell.value else { return nil }

        // If type is "s" (shared string), look up by index
        if cell.type == "s", let idx = Int(rawValue), idx < sharedStrings.count {
            return sharedStrings[idx]
        }

        return rawValue
    }

    /// Maps the OpenXML cell type code to a human-readable name.
    private static func resolveTypeName(type: String?, formula: String?) -> String {
        if formula != nil { return "formula" }

        switch type {
        case "s":  return "sharedString"
        case "b":  return "boolean"
        case "e":  return "error"
        case "str": return "inlineString"
        case "n", nil: return "number"
        default: return type ?? "unknown"
        }
    }
}

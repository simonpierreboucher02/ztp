import ArgumentParser
import Foundation
import ZTPExcel

struct ExcelCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "excel",
        abstract: "Native Excel generation and inspection",
        subcommands: [
            ExcelBuildCommand.self,
            ExcelValidateSpecCommand.self,
            ExcelImportCSVCommand.self,
            ExcelInspectCommand.self,
            ExcelSheetsCommand.self,
            ExcelPreviewCommand.self,
            ExcelCellCommand.self,
            ExcelValidateCommand.self,
        ]
    )
}

// MARK: - Build

struct ExcelBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build an XLSX file from a JSON spec"
    )

    @Argument(help: "Input JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output XLSX file path")
    var output: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: specData)

        let specResult = SpecValidator.validate(spec: spec)
        if !specResult.valid {
            let errors = specResult.errors.map { e in
                [
                    "code": e.code,
                    "message": e.message,
                    "path": e.path ?? "",
                    "hint": e.hint ?? "",
                ] as [String: String]
            }
            if json {
                let out: [String: Any] = [
                    "ok": false,
                    "tool": "ztp-excel",
                    "command": "build",
                    "errors": errors,
                ]
                printJSON(out)
            } else {
                print("Spec validation failed:")
                for e in specResult.errors {
                    print("  [\(e.code)] \(e.message)")
                }
            }
            throw ExitCode.failure
        }

        let workbook = try spec.toWorkbook()
        let styleMap = spec.toStyleMap()

        var registry = StyleRegistry()
        for (name, style) in styleMap {
            registry.register(name: name, style: style)
        }

        for sheet in spec.sheets {
            for cell in sheet.cells {
                if let format = cell.format {
                    let formatStyle = CellStyle(numberFormat: format)
                    registry.register(name: "__fmt_\(cell.address)", style: formatStyle)
                }
            }
        }

        let start = ContinuousClock.now
        let xlsxData = try XLSXPackager.package(workbook: workbook, styleRegistry: registry)

        let tempPath = output + ".tmp"
        try xlsxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) {
            try fm.removeItem(atPath: output)
        }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)
        let cellCount = workbook.sheets.reduce(0) { $0 + $1.cells.count }

        if json {
            let out: [String: Any] = [
                "ok": true,
                "tool": "ztp-excel",
                "command": "build",
                "input": specFile,
                "output": output,
                "created_files": [output],
                "warnings": [] as [String],
                "metrics": [
                    "duration_ms": elapsed,
                    "sheets": workbook.sheets.count,
                    "cells_written": cellCount,
                    "file_size_bytes": xlsxData.count,
                ] as [String: Any],
            ]
            printJSON(out)
        } else {
            print("Built \(output)")
            print("  Sheets: \(workbook.sheets.count)")
            print("  Cells: \(cellCount)")
            print("  Size: \(xlsxData.count) bytes")
            print("  Duration: \(elapsed) ms")
        }
    }
}

// MARK: - Validate Spec

struct ExcelValidateSpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate-spec",
        abstract: "Validate a workbook JSON spec"
    )

    @Argument(help: "JSON spec file to validate")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = SpecValidator.validate(jsonData: specData)

        if json {
            let errors = result.errors.map { e in
                [
                    "code": e.code,
                    "message": e.message,
                    "path": e.path ?? "",
                    "hint": e.hint ?? "",
                ] as [String: String]
            }
            let out: [String: Any] = [
                "ok": result.valid,
                "tool": "ztp-excel",
                "command": "validate-spec",
                "valid": result.valid,
                "errors": errors,
            ]
            printJSON(out)
        } else if result.valid {
            print("Spec is valid.")
        } else {
            print("Spec validation failed:")
            for e in result.errors {
                let path = e.path.map { " at \($0)" } ?? ""
                print("  [\(e.code)] \(e.message)\(path)")
                if let hint = e.hint {
                    print("    Hint: \(hint)")
                }
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - Import CSV

struct ExcelImportCSVCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-csv",
        abstract: "Import a CSV file into XLSX"
    )

    @Argument(help: "Input CSV file")
    var csvFile: String

    @Option(name: .long, help: "Output XLSX file path")
    var output: String

    @Option(name: .long, help: "Sheet name")
    var sheet: String = "Sheet1"

    @Flag(name: .long, help: "Infer cell types from values")
    var inferTypes = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let start = ContinuousClock.now

        let options = CSVImporter.Options(
            hasHeader: true,
            inferTypes: inferTypes,
            sheetName: sheet
        )
        let workbook = try CSVImporter.importCSV(at: csvFile, options: options)
        let registry = StyleRegistry()
        let xlsxData = try XLSXPackager.package(workbook: workbook, styleRegistry: registry)

        let tempPath = output + ".tmp"
        try xlsxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) {
            try fm.removeItem(atPath: output)
        }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)
        let cellCount = workbook.sheets.reduce(0) { $0 + $1.cells.count }

        if json {
            let out: [String: Any] = [
                "ok": true,
                "tool": "ztp-excel",
                "command": "import-csv",
                "input": csvFile,
                "output": output,
                "created_files": [output],
                "metrics": [
                    "duration_ms": elapsed,
                    "cells_written": cellCount,
                    "file_size_bytes": xlsxData.count,
                ] as [String: Any],
            ]
            printJSON(out)
        } else {
            print("Imported \(csvFile) → \(output)")
            print("  Cells: \(cellCount)")
            print("  Size: \(xlsxData.count) bytes")
        }
    }
}

// MARK: - Inspect

struct ExcelInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect an XLSX file"
    )

    @Argument(help: "XLSX file to inspect")
    var xlsxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try XLSXInspector.inspect(at: xlsxFile)

        if json {
            let sheets = info.sheetDetails.map { s in
                [
                    "name": s.name,
                    "rows_detected": s.rowsDetected,
                    "columns_detected": s.columnsDetected,
                ] as [String: Any]
            }
            let out: [String: Any] = [
                "ok": true,
                "tool": "ztp-excel",
                "command": "inspect",
                "workbook": [
                    "sheets": info.sheets,
                    "has_formulas": info.hasFormulas,
                    "has_styles": info.hasStyles,
                ] as [String: Any],
                "sheets": sheets,
            ]
            printJSON(out)
        } else {
            print("Workbook: \(xlsxFile)")
            print("  Sheets: \(info.sheets)")
            print("  Formulas: \(info.hasFormulas ? "yes" : "no")")
            print("  Styles: \(info.hasStyles ? "yes" : "no")")
            for s in info.sheetDetails {
                print("  [\(s.name)] \(s.rowsDetected) rows × \(s.columnsDetected) columns")
            }
        }
    }
}

// MARK: - Sheets

struct ExcelSheetsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sheets",
        abstract: "List sheets in an XLSX file"
    )

    @Argument(help: "XLSX file")
    var xlsxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try XLSXInspector.inspect(at: xlsxFile)

        if json {
            let sheets = info.sheetDetails.map { ["name": $0.name, "rows": $0.rowsDetected, "columns": $0.columnsDetected] as [String: Any] }
            let out: [String: Any] = ["ok": true, "tool": "ztp-excel", "sheets": sheets]
            printJSON(out)
        } else {
            for (i, s) in info.sheetDetails.enumerated() {
                print("\(i + 1). \(s.name) (\(s.rowsDetected) rows, \(s.columnsDetected) cols)")
            }
        }
    }
}

// MARK: - Preview

struct ExcelPreviewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Preview rows from a sheet"
    )

    @Argument(help: "XLSX file")
    var xlsxFile: String

    @Option(name: .long, help: "Sheet name")
    var sheet: String = "Sheet1"

    @Option(name: .long, help: "Max rows to preview")
    var rows: Int = 20

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let grid = try XLSXInspector.previewSheet(at: xlsxFile, sheetName: sheet, maxRows: rows)

        if json {
            let rowsArr = grid.map { row in
                row.map { $0 ?? "" }
            }
            let out: [String: Any] = [
                "ok": true,
                "tool": "ztp-excel",
                "sheet": sheet,
                "rows": rowsArr,
                "row_count": grid.count,
            ]
            printJSON(out)
        } else {
            for row in grid {
                let cells = row.map { $0 ?? "" }
                print(cells.joined(separator: "\t"))
            }
        }
    }
}

// MARK: - Cell

struct ExcelCellCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cell",
        abstract: "Inspect a single cell"
    )

    @Argument(help: "XLSX file")
    var xlsxFile: String

    @Argument(help: "Cell reference (e.g. Sheet1!B2 or B2)")
    var reference: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try XLSXInspector.inspectCell(at: xlsxFile, reference: reference)

        if json {
            var out: [String: Any] = [
                "ok": true,
                "tool": "ztp-excel",
                "address": info.address,
                "type": info.type,
            ]
            if let v = info.value { out["value"] = v }
            if let f = info.formula { out["formula"] = f }
            if let s = info.styleIndex { out["style_index"] = s }
            printJSON(out)
        } else {
            print("Cell: \(info.address)")
            print("  Type: \(info.type)")
            if let v = info.value { print("  Value: \(v)") }
            if let f = info.formula { print("  Formula: \(f)") }
            if let s = info.styleIndex { print("  Style index: \(s)") }
        }
    }
}

// MARK: - Validate XLSX

struct ExcelValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate an XLSX file"
    )

    @Argument(help: "XLSX file to validate")
    var xlsxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let result = try XLSXValidator.validate(at: xlsxFile)

        if json {
            let checks = result.checks.map { c in
                [
                    "check": c.name,
                    "passed": c.passed,
                    "message": c.message ?? "",
                ] as [String: Any]
            }
            let out: [String: Any] = [
                "ok": result.valid,
                "tool": "ztp-excel",
                "command": "validate",
                "valid": result.valid,
                "checks": checks,
            ]
            printJSON(out)
        } else {
            print("Validation: \(result.valid ? "PASSED" : "FAILED")")
            for c in result.checks {
                let icon = c.passed ? "OK" : "FAIL"
                let msg = c.message.map { " — \($0)" } ?? ""
                print("  \(icon)  \(c.name)\(msg)")
            }
            if !result.valid {
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Helpers

private func printJSON(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
    let elapsed = start.duration(to: .now)
    return elapsed.components.seconds * 1000
        + elapsed.components.attoseconds / 1_000_000_000_000_000
}

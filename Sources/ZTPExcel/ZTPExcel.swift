import Foundation
import ZTPCore
import ZTPProtocols

public struct ZTPExcelTool: ZTPTool {
    public let manifest = ToolManifest(
        name: "ztp-excel",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: ["xlsx.create", "xlsx.inspect", "xlsx.validate", "csv.import"],
        permissions: ["filesystem": true, "network": false]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified")
            )
        }

        let start = ContinuousClock.now

        switch command {
        case "build":
            return try await executeBuild(input: input, context: context, start: start)
        case "validate-spec":
            return try executeValidateSpec(input: input, start: start)
        case "validate":
            return try executeValidate(input: input, start: start)
        case "inspect":
            return try executeInspect(input: input, start: start)
        case "import-csv":
            return try executeImportCSV(input: input, context: context, start: start)
        default:
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
            )
        }
    }

    private func executeBuild(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) async throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No input spec file specified"))
        }
        guard let outputPath = input.string(for: "output") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path specified"))
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(WorkbookSpec.self, from: specData)
        let workbook = try spec.toWorkbook()
        let styleMap = spec.toStyleMap()

        var registry = StyleRegistry()
        for (name, style) in styleMap {
            registry.register(name: name, style: style)
        }

        for sheet in spec.sheets {
            for cell in sheet.cells {
                if let format = cell.format, cell.style == nil {
                    let formatStyle = CellStyle(numberFormat: format)
                    registry.register(name: "__format_\(cell.address)_\(format)", style: formatStyle)
                }
            }
        }

        let xlsxData = try XLSXPackager.package(workbook: workbook, styleRegistry: registry)

        let tempPath = outputPath + ".tmp"
        try xlsxData.write(to: URL(fileURLWithPath: tempPath))

        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        try fm.moveItem(atPath: tempPath, toPath: outputPath)

        let elapsed = elapsedMs(from: start)
        let cellCount = workbook.sheets.reduce(0) { $0 + $1.cells.count }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("build"),
            "input": .string(specPath),
            "output": .string(outputPath),
            "sheets": .int(workbook.sheets.count),
            "cells_written": .int(cellCount),
            "file_size_bytes": .int(xlsxData.count),
        ])
    }

    private func executeValidateSpec(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified"))
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let result = SpecValidator.validate(jsonData: specData)
        let elapsed = elapsedMs(from: start)

        if result.valid {
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("validate-spec"),
                "valid": .bool(true),
            ])
        } else {
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("validate-spec"),
                "valid": .bool(false),
                "error_count": .int(result.errors.count),
            ])
        }
    }

    private func executeValidate(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let filePath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No xlsx file specified"))
        }

        let result = try XLSXValidator.validate(at: filePath)
        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("validate"),
            "valid": .bool(result.valid),
            "checks_passed": .int(result.checks.filter(\.passed).count),
            "checks_total": .int(result.checks.count),
        ])
    }

    private func executeInspect(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let filePath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No xlsx file specified"))
        }

        let info = try XLSXInspector.inspect(at: filePath)
        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("inspect"),
            "sheets": .int(info.sheets),
            "has_formulas": .bool(info.hasFormulas),
            "has_styles": .bool(info.hasStyles),
        ])
    }

    private func executeImportCSV(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let csvPath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No CSV file specified"))
        }
        guard let outputPath = input.string(for: "output") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path specified"))
        }

        let inferTypes = input.bool(for: "infer_types") ?? false
        let sheetName = input.string(for: "sheet") ?? "Sheet1"

        let options = CSVImporter.Options(
            hasHeader: true,
            inferTypes: inferTypes,
            sheetName: sheetName
        )

        let workbook = try CSVImporter.importCSV(at: csvPath, options: options)
        let registry = StyleRegistry()
        let xlsxData = try XLSXPackager.package(workbook: workbook, styleRegistry: registry)

        let tempPath = outputPath + ".tmp"
        try xlsxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        try fm.moveItem(atPath: tempPath, toPath: outputPath)

        let elapsed = elapsedMs(from: start)
        let cellCount = workbook.sheets.reduce(0) { $0 + $1.cells.count }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("import-csv"),
            "input": .string(csvPath),
            "output": .string(outputPath),
            "cells_written": .int(cellCount),
            "file_size_bytes": .int(xlsxData.count),
        ])
    }

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

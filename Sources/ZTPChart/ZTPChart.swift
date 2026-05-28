import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTP Chart Tool

public struct ZTPChartTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-chart",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "chart.create",
            "chart.validate",
            "chart.inspect",
            "chart.export.png",
            "chart.export.svg",
            "chart.export.pdf"
        ],
        permissions: ["filesystem": true, "network": false]
    )

    public init() {}

    // MARK: - Execute

    public func execute(
        input: ToolInput,
        context: ToolContext
    ) async throws -> ToolResult {
        let startTime = DispatchTime.now()
        let command = input.string(for: "command") ?? "build"

        do {
            let result: ToolResult

            switch command {
            case "build":
                result = try executeBuild(input: input, context: context, startTime: startTime)

            case "validate-spec":
                result = try executeValidateSpec(input: input, startTime: startTime)

            case "inspect":
                result = try executeInspect(input: input, startTime: startTime)

            case "data-summary":
                result = try executeDataSummary(input: input, context: context, startTime: startTime)

            case "themes":
                result = executeListThemes(startTime: startTime)

            default:
                return ToolResult.failure(
                    tool: manifest.name,
                    durationMs: durationMs(from: startTime),
                    error: ToolErrorInfo(
                        code: "UNKNOWN_COMMAND",
                        message: "Unknown command '\(command)'. Supported: build, validate-spec, inspect, data-summary, themes"
                    )
                )
            }

            return result
        } catch {
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: durationMs(from: startTime),
                error: ToolErrorInfo(
                    code: "EXECUTION_ERROR",
                    message: error.localizedDescription
                )
            )
        }
    }

    // MARK: - Build Command

    private func executeBuild(
        input: ToolInput,
        context: ToolContext,
        startTime: DispatchTime
    ) throws -> ToolResult {
        let specJSON = try resolveSpecJSON(input: input, context: context)

        let formatString = input.string(for: "format") ?? "svg"
        guard let format = ChartEngine.OutputFormat(rawValue: formatString) else {
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: durationMs(from: startTime),
                error: ToolErrorInfo(
                    code: "INVALID_FORMAT",
                    message: "Unsupported output format '\(formatString)'. Use png, svg, or pdf."
                )
            )
        }

        let spec = try ChartSpec.from(json: specJSON)
        let basePath = input.string(for: "spec_file")
            ?? context.workingDirectory.path

        let buildResult = try ChartEngine.build(
            spec: spec,
            basePath: basePath,
            format: format
        )

        // Write output file atomically
        let outputPath = input.string(for: "output")
            ?? "chart.\(format.rawValue)"
        let resolvedOutput: String
        if outputPath.hasPrefix("/") {
            resolvedOutput = outputPath
        } else {
            resolvedOutput = context.workingDirectory
                .appendingPathComponent(outputPath).path
        }

        let outputURL = URL(fileURLWithPath: resolvedOutput)
        try buildResult.data.write(to: outputURL, options: .atomic)

        return ToolResult.success(
            tool: manifest.name,
            durationMs: durationMs(from: startTime),
            data: [
                "output": .string(resolvedOutput),
                "format": .string(format.rawValue),
                "chart_type": .string(buildResult.chartType.rawValue),
                "width": .int(buildResult.width),
                "height": .int(buildResult.height),
                "points_rendered": .int(buildResult.pointsRendered),
                "bytes": .int(buildResult.data.count)
            ]
        )
    }

    // MARK: - Validate Spec Command

    private func executeValidateSpec(
        input: ToolInput,
        startTime: DispatchTime
    ) throws -> ToolResult {
        let specJSON: Data

        if let specString = input.string(for: "spec") {
            guard let data = specString.data(using: .utf8) else {
                return ToolResult.failure(
                    tool: manifest.name,
                    durationMs: durationMs(from: startTime),
                    error: ToolErrorInfo(code: "INVALID_INPUT", message: "Cannot encode spec as UTF-8")
                )
            }
            specJSON = data
        } else if let specFile = input.string(for: "spec_file") {
            specJSON = try Data(contentsOf: URL(fileURLWithPath: specFile))
        } else {
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: durationMs(from: startTime),
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "Provide 'spec' (JSON string) or 'spec_file' (path)")
            )
        }

        let validationResult = ChartSpecValidator.validate(jsonData: specJSON)

        var errorValues: [JSONValue] = []
        for e in validationResult.errors {
            var obj: [String: JSONValue] = [
                "code": .string(e.code),
                "message": .string(e.message)
            ]
            if let path = e.path { obj["path"] = .string(path) }
            if let hint = e.hint { obj["hint"] = .string(hint) }
            errorValues.append(.object(obj))
        }

        return ToolResult.success(
            tool: manifest.name,
            durationMs: durationMs(from: startTime),
            data: [
                "valid": .bool(validationResult.valid),
                "error_count": .int(validationResult.errors.count),
                "errors": .array(errorValues)
            ]
        )
    }

    // MARK: - Inspect Command

    private func executeInspect(
        input: ToolInput,
        startTime: DispatchTime
    ) throws -> ToolResult {
        let specJSON: Data

        if let specString = input.string(for: "spec") {
            guard let data = specString.data(using: .utf8) else {
                return ToolResult.failure(
                    tool: manifest.name,
                    durationMs: durationMs(from: startTime),
                    error: ToolErrorInfo(code: "INVALID_INPUT", message: "Cannot encode spec as UTF-8")
                )
            }
            specJSON = data
        } else if let specFile = input.string(for: "spec_file") {
            specJSON = try Data(contentsOf: URL(fileURLWithPath: specFile))
        } else {
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: durationMs(from: startTime),
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "Provide 'spec' or 'spec_file'")
            )
        }

        let info = try ChartInspector.inspect(jsonData: specJSON)

        var data: [String: JSONValue] = [
            "chart_type": .string(info.chartType),
            "width": .int(info.width),
            "height": .int(info.height),
            "series_count": .int(info.seriesCount),
            "data_points": .int(info.dataPoints),
            "has_title": .bool(info.hasTitle),
            "has_legend": .bool(info.hasLegend),
            "has_grid": .bool(info.hasGrid)
        ]
        if let theme = info.theme {
            data["theme"] = .string(theme)
        }

        return ToolResult.success(
            tool: manifest.name,
            durationMs: durationMs(from: startTime),
            data: data
        )
    }

    // MARK: - Data Summary Command

    private func executeDataSummary(
        input: ToolInput,
        context: ToolContext,
        startTime: DispatchTime
    ) throws -> ToolResult {
        let specJSON = try resolveSpecJSON(input: input, context: context)
        let basePath = input.string(for: "spec_file") ?? context.workingDirectory.path

        let summary = try ChartInspector.dataSummary(jsonData: specJSON, basePath: basePath)

        var columnValues: [JSONValue] = []
        for col in summary.columnSummaries {
            var obj: [String: JSONValue] = [
                "name": .string(col.name),
                "type": .string(col.type),
                "count": .int(col.count),
                "missing": .int(col.missing)
            ]
            if let minVal = col.min { obj["min"] = .double(minVal) }
            if let maxVal = col.max { obj["max"] = .double(maxVal) }
            if let meanVal = col.mean { obj["mean"] = .double(meanVal) }
            columnValues.append(.object(obj))
        }

        return ToolResult.success(
            tool: manifest.name,
            durationMs: durationMs(from: startTime),
            data: [
                "columns": .array(summary.columns.map { .string($0) }),
                "row_count": .int(summary.rowCount),
                "column_summaries": .array(columnValues)
            ]
        )
    }

    // MARK: - Themes Command

    private func executeListThemes(startTime: DispatchTime) -> ToolResult {
        let themes = ThemeInspector.listThemes()

        let themeValues: [JSONValue] = themes.map { t in
            .object([
                "name": .string(t.name),
                "background": .string(t.background),
                "font": .string(t.font),
                "palette_size": .int(t.paletteSize)
            ])
        }

        return ToolResult.success(
            tool: manifest.name,
            durationMs: durationMs(from: startTime),
            data: [
                "count": .int(themes.count),
                "themes": .array(themeValues)
            ]
        )
    }

    // MARK: - Helpers

    private func resolveSpecJSON(input: ToolInput, context: ToolContext) throws -> Data {
        if let specString = input.string(for: "spec") {
            guard let data = specString.data(using: .utf8) else {
                throw ToolError.invalidInput("Cannot encode spec as UTF-8")
            }
            return data
        } else if let specFile = input.string(for: "spec_file") {
            let path: String
            if specFile.hasPrefix("/") {
                path = specFile
            } else {
                path = context.workingDirectory.appendingPathComponent(specFile).path
            }
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } else {
            throw ToolError.invalidInput("Provide 'spec' (JSON string) or 'spec_file' (file path)")
        }
    }

    private func durationMs(from start: DispatchTime) -> Int64 {
        let end = DispatchTime.now()
        let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Int64(nanos / 1_000_000)
    }
}

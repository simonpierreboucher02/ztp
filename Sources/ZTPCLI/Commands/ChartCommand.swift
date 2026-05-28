import ArgumentParser
import Foundation
import ZTPChart

struct ChartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chart",
        abstract: "Native chart and visualization generation",
        subcommands: [
            ChartBuildCommand.self,
            ChartValidateSpecCommand.self,
            ChartInspectCommand.self,
            ChartDataSummaryCommand.self,
            ChartThemesCommand.self,
        ]
    )
}

struct ChartBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build", abstract: "Build a chart from a JSON spec")

    @Argument(help: "Input JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output file path")
    var output: String

    @Option(name: .long, help: "Output format: png, svg, pdf")
    var format: String = "png"

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        guard let fmt = ChartEngine.OutputFormat(rawValue: format) else {
            if json {
                printJSON(["ok": false, "tool": "ztp-chart", "errors": [["code": "INVALID_FORMAT", "message": "Format must be png, svg, or pdf"]] as [[String: String]]] as [String: Any])
            } else {
                print("Invalid format: \(format). Use png, svg, or pdf.")
            }
            throw ExitCode.failure
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(ChartSpec.self, from: specData)

        let specResult = ChartSpecValidator.validate(spec: spec)
        if !specResult.valid {
            if json {
                let errors = specResult.errors.filter { !$0.code.hasPrefix("UNKNOWN_THEME") && !$0.code.hasPrefix("UNREASONABLE") }
                    .map { ["code": $0.code, "message": $0.message, "path": $0.path ?? "", "hint": $0.hint ?? ""] as [String: String] }
                if !errors.isEmpty {
                    printJSON(["ok": false, "tool": "ztp-chart", "command": "build", "errors": errors] as [String: Any])
                    throw ExitCode.failure
                }
            } else {
                print("Spec validation failed:")
                for e in specResult.errors { print("  [\(e.code)] \(e.message)") }
                throw ExitCode.failure
            }
        }

        let start = ContinuousClock.now
        let basePath = (specFile as NSString).deletingLastPathComponent
        let result = try ChartEngine.build(spec: spec, basePath: basePath, format: fmt)

        let tempPath = output + ".tmp"
        try result.data.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)

        if json {
            printJSON([
                "ok": true, "tool": "ztp-chart", "command": "build",
                "input": specFile, "output": output,
                "created_files": [output],
                "warnings": [] as [String],
                "metrics": [
                    "duration_ms": elapsed,
                    "chart_type": result.chartType.rawValue,
                    "format": result.format.rawValue,
                    "width": result.width,
                    "height": result.height,
                    "points_rendered": result.pointsRendered,
                    "file_size_bytes": result.data.count,
                ] as [String: Any],
            ] as [String: Any])
        } else {
            print("Built \(output)")
            print("  Type: \(result.chartType.rawValue)")
            print("  Format: \(result.format.rawValue)")
            print("  Size: \(result.width)×\(result.height)")
            print("  Points: \(result.pointsRendered)")
            print("  File: \(result.data.count) bytes")
            print("  Duration: \(elapsed) ms")
        }
    }
}

struct ChartValidateSpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-spec", abstract: "Validate a chart JSON spec")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = ChartSpecValidator.validate(jsonData: specData)

        if json {
            let errors = result.errors.map { ["code": $0.code, "message": $0.message, "path": $0.path ?? "", "hint": $0.hint ?? ""] as [String: String] }
            printJSON(["ok": result.valid, "tool": "ztp-chart", "command": "validate-spec", "valid": result.valid, "errors": errors] as [String: Any])
        } else if result.valid {
            print("Spec is valid.")
        } else {
            print("Spec validation failed:")
            for e in result.errors { print("  [\(e.code)] \(e.message)") }
            throw ExitCode.failure
        }
    }
}

struct ChartInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a chart spec")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let info = try ChartInspector.inspect(jsonData: specData)

        if json {
            var chart: [String: Any] = [
                "type": info.chartType,
                "width": info.width, "height": info.height,
                "series": info.seriesCount, "points": info.dataPoints,
                "has_title": info.hasTitle, "has_legend": info.hasLegend, "has_grid": info.hasGrid,
            ]
            if let t = info.theme { chart["theme"] = t }
            printJSON(["ok": true, "tool": "ztp-chart", "command": "inspect", "chart": chart] as [String: Any])
        } else {
            print("Chart: \(info.chartType)")
            print("  Size: \(info.width)×\(info.height)")
            print("  Series: \(info.seriesCount)")
            print("  Data points: \(info.dataPoints)")
            if let t = info.theme { print("  Theme: \(t)") }
        }
    }
}

struct ChartDataSummaryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "data-summary", abstract: "Summarize chart data")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let basePath = (specFile as NSString).deletingLastPathComponent
        let summary = try ChartInspector.dataSummary(jsonData: specData, basePath: basePath)

        if json {
            let cols = summary.columnSummaries.map { c in
                var d: [String: Any] = ["name": c.name, "type": c.type, "count": c.count, "missing": c.missing]
                if let min = c.min { d["min"] = min }
                if let max = c.max { d["max"] = max }
                if let mean = c.mean { d["mean"] = mean }
                return d
            }
            printJSON(["ok": true, "tool": "ztp-chart", "rows": summary.rowCount, "columns": summary.columns, "summary": cols] as [String: Any])
        } else {
            print("Rows: \(summary.rowCount)")
            print("Columns: \(summary.columns.joined(separator: ", "))")
            for c in summary.columnSummaries {
                var info = "\(c.name) (\(c.type)): \(c.count) values"
                if c.missing > 0 { info += ", \(c.missing) missing" }
                if let min = c.min, let max = c.max { info += ", range [\(min)–\(max)]" }
                if let mean = c.mean { info += ", mean \(String(format: "%.2f", mean))" }
                print("  \(info)")
            }
        }
    }
}

struct ChartThemesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "themes", abstract: "List available chart themes")

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let themes = ThemeInspector.listThemes()

        if json {
            let items = themes.map { ["name": $0.name, "background": $0.background, "font": $0.font, "palette_size": $0.paletteSize] as [String: Any] }
            printJSON(["ok": true, "tool": "ztp-chart", "themes": items] as [String: Any])
        } else {
            for t in themes {
                print("\(t.name)  (bg: #\(t.background), font: \(t.font), \(t.paletteSize) colors)")
            }
        }
    }
}

private func printJSON(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) { print(str) }
}

private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
    let elapsed = start.duration(to: .now)
    return elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
}

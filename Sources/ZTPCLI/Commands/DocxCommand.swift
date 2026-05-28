import ArgumentParser
import Foundation
import ZTPDocx

struct DocxCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docx",
        abstract: "Native DOCX generation and inspection",
        subcommands: [
            DocxBuildCommand.self,
            DocxValidateSpecCommand.self,
            DocxInspectCommand.self,
            DocxOutlineCommand.self,
            DocxTextCommand.self,
            DocxTablesCommand.self,
            DocxValidateCommand.self,
        ]
    )
}

// MARK: - Build

struct DocxBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build a DOCX file from a JSON spec"
    )

    @Argument(help: "Input JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output DOCX file path")
    var output: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(DocumentSpec.self, from: specData)

        let specResult = DocxSpecValidator.validate(spec: spec)
        if !specResult.valid {
            if json {
                let errors = specResult.errors.map { e in
                    ["code": e.code, "message": e.message, "path": e.path ?? "", "hint": e.hint ?? ""] as [String: String]
                }
                printJSON(["ok": false, "tool": "ztp-docx", "command": "build", "errors": errors] as [String: Any])
            } else {
                print("Spec validation failed:")
                for e in specResult.errors {
                    print("  [\(e.code)] \(e.message)")
                }
            }
            throw ExitCode.failure
        }

        let document = try spec.toDocument()
        let styleMap = spec.toStyleMap()

        var registry = DocxStyleRegistry()
        for (name, style) in styleMap {
            registry.register(name: name, style: style)
        }

        let start = ContinuousClock.now
        let basePath = (specFile as NSString).deletingLastPathComponent
        let docxData = try DocxPackager.package(document: document, styleRegistry: registry, basePath: basePath)

        let tempPath = output + ".tmp"
        try docxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)

        if json {
            printJSON([
                "ok": true,
                "tool": "ztp-docx",
                "command": "build",
                "input": specFile,
                "output": output,
                "created_files": [output],
                "warnings": [] as [String],
                "metrics": [
                    "duration_ms": elapsed,
                    "sections": document.sections.count,
                    "paragraphs": document.totalParagraphs,
                    "tables": document.totalTables,
                    "images": document.totalImages,
                    "file_size_bytes": docxData.count,
                ] as [String: Any],
            ] as [String: Any])
        } else {
            print("Built \(output)")
            print("  Sections: \(document.sections.count)")
            print("  Paragraphs: \(document.totalParagraphs)")
            print("  Tables: \(document.totalTables)")
            print("  Images: \(document.totalImages)")
            print("  Size: \(docxData.count) bytes")
            print("  Duration: \(elapsed) ms")
        }
    }
}

// MARK: - Validate Spec

struct DocxValidateSpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate-spec",
        abstract: "Validate a document JSON spec"
    )

    @Argument(help: "JSON spec file to validate")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = DocxSpecValidator.validate(jsonData: specData)

        if json {
            let errors = result.errors.map { e in
                ["code": e.code, "message": e.message, "path": e.path ?? "", "hint": e.hint ?? ""] as [String: String]
            }
            printJSON(["ok": result.valid, "tool": "ztp-docx", "command": "validate-spec", "valid": result.valid, "errors": errors] as [String: Any])
        } else if result.valid {
            print("Spec is valid.")
        } else {
            print("Spec validation failed:")
            for e in result.errors {
                let path = e.path.map { " at \($0)" } ?? ""
                print("  [\(e.code)] \(e.message)\(path)")
                if let hint = e.hint { print("    Hint: \(hint)") }
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - Inspect

struct DocxInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect a DOCX file"
    )

    @Argument(help: "DOCX file to inspect")
    var docxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try DocxInspector.inspect(at: docxFile)

        if json {
            var doc: [String: Any] = [
                "paragraphs": info.paragraphs,
                "tables": info.tables,
                "images": info.images,
                "headings": info.headings,
            ]
            if let t = info.title { doc["title"] = t }
            if let a = info.author { doc["author"] = a }
            printJSON(["ok": true, "tool": "ztp-docx", "command": "inspect", "document": doc] as [String: Any])
        } else {
            if let t = info.title { print("Title: \(t)") }
            if let a = info.author { print("Author: \(a)") }
            print("Paragraphs: \(info.paragraphs)")
            print("Headings: \(info.headings)")
            print("Tables: \(info.tables)")
            print("Images: \(info.images)")
        }
    }
}

// MARK: - Outline

struct DocxOutlineCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outline",
        abstract: "Extract document outline (headings)"
    )

    @Argument(help: "DOCX file")
    var docxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let headings = try DocxInspector.outline(at: docxFile)

        if json {
            let items = headings.map { ["level": $0.level, "text": $0.text] as [String: Any] }
            printJSON(["ok": true, "tool": "ztp-docx", "headings": items] as [String: Any])
        } else {
            for h in headings {
                let indent = String(repeating: "  ", count: h.level - 1)
                print("\(indent)H\(h.level): \(h.text)")
            }
        }
    }
}

// MARK: - Text

struct DocxTextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Extract plain text from a DOCX file"
    )

    @Argument(help: "DOCX file")
    var docxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let text = try DocxInspector.extractText(at: docxFile)

        if json {
            printJSON(["ok": true, "tool": "ztp-docx", "text": text] as [String: Any])
        } else {
            print(text)
        }
    }
}

// MARK: - Tables

struct DocxTablesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tables",
        abstract: "Extract tables from a DOCX file"
    )

    @Argument(help: "DOCX file")
    var docxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let tables = try DocxInspector.extractTables(at: docxFile)

        if json {
            let items = tables.map { t in
                ["rows": t.rows, "columns": t.columns, "preview": t.preview] as [String: Any]
            }
            printJSON(["ok": true, "tool": "ztp-docx", "tables": items, "count": tables.count] as [String: Any])
        } else {
            for (i, t) in tables.enumerated() {
                print("Table \(i + 1): \(t.rows) rows × \(t.columns) columns")
                for row in t.preview {
                    print("  \(row.joined(separator: "\t"))")
                }
            }
        }
    }
}

// MARK: - Validate

struct DocxValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a DOCX file"
    )

    @Argument(help: "DOCX file to validate")
    var docxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let result = try DocxValidator.validate(at: docxFile)

        if json {
            let checks = result.checks.map { c in
                ["check": c.name, "passed": c.passed, "message": c.message ?? ""] as [String: Any]
            }
            printJSON(["ok": result.valid, "tool": "ztp-docx", "command": "validate", "valid": result.valid, "checks": checks] as [String: Any])
        } else {
            print("Validation: \(result.valid ? "PASSED" : "FAILED")")
            for c in result.checks {
                let icon = c.passed ? "OK" : "FAIL"
                let msg = c.message.map { " — \($0)" } ?? ""
                print("  \(icon)  \(c.name)\(msg)")
            }
            if !result.valid { throw ExitCode.failure }
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

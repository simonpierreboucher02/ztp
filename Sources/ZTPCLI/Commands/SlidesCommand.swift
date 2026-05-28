import ArgumentParser
import Foundation
import ZTPSlides

struct SlidesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "slides",
        abstract: "Native PPTX generation and inspection",
        subcommands: [
            SlidesBuildCommand.self,
            SlidesValidateSpecCommand.self,
            SlidesInspectCommand.self,
            SlidesOutlineCommand.self,
            SlidesPreviewCommand.self,
            SlidesTextCommand.self,
            SlidesValidateCommand.self,
        ]
    )
}

struct SlidesBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build", abstract: "Build a PPTX file from a JSON spec")

    @Argument(help: "Input JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output PPTX file path")
    var output: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(PresentationSpec.self, from: specData)

        let specResult = SlidesSpecValidator.validate(spec: spec)
        if !specResult.valid {
            if json {
                let errors = specResult.errors.map { ["code": $0.code, "message": $0.message, "path": $0.path ?? "", "hint": $0.hint ?? ""] as [String: String] }
                printJSON(["ok": false, "tool": "ztp-slides", "command": "build", "errors": errors] as [String: Any])
            } else {
                print("Spec validation failed:")
                for e in specResult.errors { print("  [\(e.code)] \(e.message)") }
            }
            throw ExitCode.failure
        }

        let presentation = try spec.toPresentation()
        let start = ContinuousClock.now
        let basePath = (specFile as NSString).deletingLastPathComponent
        let pptxData = try PptxPackager.package(presentation: presentation, basePath: basePath)

        let tempPath = output + ".tmp"
        try pptxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)

        if json {
            printJSON([
                "ok": true, "tool": "ztp-slides", "command": "build",
                "input": specFile, "output": output,
                "created_files": [output],
                "warnings": [] as [String],
                "metrics": [
                    "duration_ms": elapsed,
                    "slides": presentation.totalSlides,
                    "images": presentation.totalImages,
                    "tables": presentation.totalTables,
                    "file_size_bytes": pptxData.count,
                ] as [String: Any],
            ] as [String: Any])
        } else {
            print("Built \(output)")
            print("  Slides: \(presentation.totalSlides)")
            print("  Tables: \(presentation.totalTables)")
            print("  Images: \(presentation.totalImages)")
            print("  Size: \(pptxData.count) bytes")
            print("  Duration: \(elapsed) ms")
        }
    }
}

struct SlidesValidateSpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-spec", abstract: "Validate a presentation JSON spec")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = SlidesSpecValidator.validate(jsonData: specData)

        if json {
            let errors = result.errors.map { ["code": $0.code, "message": $0.message, "path": $0.path ?? "", "hint": $0.hint ?? ""] as [String: String] }
            printJSON(["ok": result.valid, "tool": "ztp-slides", "command": "validate-spec", "valid": result.valid, "errors": errors] as [String: Any])
        } else if result.valid {
            print("Spec is valid.")
        } else {
            print("Spec validation failed:")
            for e in result.errors { print("  [\(e.code)] \(e.message)") }
            throw ExitCode.failure
        }
    }
}

struct SlidesInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a PPTX file")

    @Argument(help: "PPTX file")
    var pptxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try SlidesInspector.inspect(at: pptxFile)

        if json {
            var doc: [String: Any] = ["slides": info.slides, "images": info.images, "tables": info.tables]
            if let t = info.title { doc["title"] = t }
            if let a = info.author { doc["author"] = a }
            if let th = info.theme { doc["theme"] = th }
            printJSON(["ok": true, "tool": "ztp-slides", "command": "inspect", "presentation": doc] as [String: Any])
        } else {
            if let t = info.title { print("Title: \(t)") }
            if let a = info.author { print("Author: \(a)") }
            print("Slides: \(info.slides)")
            print("Images: \(info.images)")
            print("Tables: \(info.tables)")
            if let th = info.theme { print("Theme: \(th)") }
        }
    }
}

struct SlidesOutlineCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "outline", abstract: "Extract presentation outline")

    @Argument(help: "PPTX file")
    var pptxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let slides = try SlidesInspector.outline(at: pptxFile)

        if json {
            let items = slides.map { s in
                var d: [String: Any] = ["index": s.index]
                if let t = s.title { d["title"] = t }
                if let p = s.textPreview { d["preview"] = p }
                return d
            }
            printJSON(["ok": true, "tool": "ztp-slides", "slides": items] as [String: Any])
        } else {
            for s in slides {
                let title = s.title ?? "(untitled)"
                print("Slide \(s.index): \(title)")
                if let p = s.textPreview { print("  \(p)") }
            }
        }
    }
}

struct SlidesPreviewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preview", abstract: "Preview slide contents")

    @Argument(help: "PPTX file")
    var pptxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let previews = try SlidesInspector.preview(at: pptxFile)

        if json {
            let items = previews.map { p in
                var d: [String: Any] = ["index": p.index, "elements": p.elements]
                if let t = p.title { d["title"] = t }
                return d
            }
            printJSON(["ok": true, "tool": "ztp-slides", "slides": items] as [String: Any])
        } else {
            for p in previews {
                let title = p.title ?? "(untitled)"
                print("Slide \(p.index): \(title)")
                for e in p.elements { print("  - \(e)") }
            }
        }
    }
}

struct SlidesTextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "text", abstract: "Extract all text from a PPTX file")

    @Argument(help: "PPTX file")
    var pptxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let text = try SlidesInspector.extractText(at: pptxFile)
        if json {
            printJSON(["ok": true, "tool": "ztp-slides", "text": text] as [String: Any])
        } else {
            print(text)
        }
    }
}

struct SlidesValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate a PPTX file")

    @Argument(help: "PPTX file")
    var pptxFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let result = try SlidesValidator.validate(at: pptxFile)

        if json {
            let checks = result.checks.map { ["check": $0.name, "passed": $0.passed, "message": $0.message ?? ""] as [String: Any] }
            printJSON(["ok": result.valid, "tool": "ztp-slides", "command": "validate", "valid": result.valid, "checks": checks] as [String: Any])
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

private func printJSON(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) { print(str) }
}

private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
    let elapsed = start.duration(to: .now)
    return elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
}

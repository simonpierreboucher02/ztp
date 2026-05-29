import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTPOCRTool

/// Local OCR over images, PDFs, and screen captures using Apple's Vision
/// framework. Entirely on-device — no network access.
public struct ZTPOCRTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-ocr",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "image",
            "pdf",
            "screen",
            "languages",
        ],
        permissions: [
            "filesystem": true,
            "screenshots": true,
        ]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified."))
        }
        let start = ContinuousClock.now
        do {
            switch command {
            case "image":   return try runImage(input: input, start: start)
            case "pdf":     return try runPDF(input: input, start: start)
            case "screen":  return try runScreen(input: input, start: start)
            case "languages": return runLanguages(input: input, start: start)
            default:
                return .failure(tool: manifest.name, error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)"))
            }
        } catch {
            return .failure(tool: manifest.name, durationMs: ems(start), error: ToolErrorInfo(code: "EXECUTION_FAILED", message: "\(error)"))
        }
    }

    // MARK: - Commands

    private func runImage(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "input") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No input image path."))
        }
        let langs = parseLanguages(input.string(for: "languages"))
        let fast = input.bool(for: "fast") ?? false
        let result = try OCREngine.recognizeImage(path: path, languages: langs, fast: fast)
        try writeOutputIfRequested(input: input, text: result.text)
        return .success(tool: manifest.name, durationMs: ems(start), data: ocrData(command: "image", source: path, results: [result]))
    }

    private func runPDF(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "input") else {
            return .failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No input PDF path."))
        }
        let langs = parseLanguages(input.string(for: "languages"))
        let fast = input.bool(for: "fast") ?? false
        let dpi = Double(input.int(for: "dpi") ?? 200)
        let pages = PDFRasterizer.parsePageRange(input.string(for: "pages"))

        let rendered = try PDFRasterizer.pageImages(path: path, pageIndices: pages, dpi: dpi)
        var results: [OCRResult] = []
        for (idx, image) in rendered {
            let r = try OCREngine.recognize(cgImage: image, languages: langs, fast: fast)
            results.append(OCRResult(text: r.text, lines: r.lines, language: r.language, pageIndex: idx))
        }
        let combined = results.map(\.text).joined(separator: "\n\n")
        try writeOutputIfRequested(input: input, text: combined)
        return .success(tool: manifest.name, durationMs: ems(start), data: ocrData(command: "pdf", source: path, results: results))
    }

    private func runScreen(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        let langs = parseLanguages(input.string(for: "languages"))
        let fast = input.bool(for: "fast") ?? false
        let result = try OCREngine.recognizeScreen(languages: langs, fast: fast)
        try writeOutputIfRequested(input: input, text: result.text)
        return .success(tool: manifest.name, durationMs: ems(start), data: ocrData(command: "screen", source: "<screen>", results: [result]))
    }

    private func runLanguages(input: ToolInput, start: ContinuousClock.Instant) -> ToolResult {
        let fast = input.bool(for: "fast") ?? false
        let langs = OCREngine.supportedLanguages(fast: fast)
        return .success(tool: manifest.name, durationMs: ems(start), data: [
            "command": .string("languages"),
            "languages": .array(langs.map { .string($0) }),
            "count": .int(langs.count),
        ])
    }

    // MARK: - Helpers

    private func parseLanguages(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0) }
    }

    private func writeOutputIfRequested(input: ToolInput, text: String) throws {
        guard let out = input.string(for: "output"), !out.isEmpty else { return }
        let expanded = (out as NSString).expandingTildeInPath
        try text.write(toFile: expanded, atomically: true, encoding: .utf8)
    }

    private func ocrData(command: String, source: String, results: [OCRResult]) -> [String: JSONValue] {
        let fullText = results.map(\.text).joined(separator: command == "pdf" ? "\n\n" : "\n")
        let pageValues: [JSONValue] = results.map { r in
            var obj: [String: JSONValue] = [
                "text": .string(r.text),
                "line_count": .int(r.lines.count),
                "char_count": .int(r.text.count),
            ]
            if let p = r.pageIndex { obj["page"] = .int(p + 1) }
            obj["lines"] = .array(r.lines.prefix(500).map { line in
                .object([
                    "text": .string(line.text),
                    "confidence": .double((line.confidence * 1000).rounded() / 1000),
                    "bbox": .array([.double(line.x), .double(line.y), .double(line.width), .double(line.height)]),
                ])
            })
            return .object(obj)
        }
        var data: [String: JSONValue] = [
            "command": .string(command),
            "source": .string(source),
            "text": .string(fullText),
            "char_count": .int(fullText.count),
            "page_count": .int(results.count),
        ]
        if results.count > 1 || command == "pdf" {
            data["pages"] = .array(pageValues)
        } else if let first = results.first {
            data["lines"] = .array(first.lines.prefix(500).map { line in
                .object([
                    "text": .string(line.text),
                    "confidence": .double((line.confidence * 1000).rounded() / 1000),
                    "bbox": .array([.double(line.x), .double(line.y), .double(line.width), .double(line.height)]),
                ])
            })
        }
        return data
    }

    private func ems(_ start: ContinuousClock.Instant) -> Int64 {
        let e = start.duration(to: .now)
        return e.components.seconds * 1000 + e.components.attoseconds / 1_000_000_000_000_000
    }
}

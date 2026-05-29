import ArgumentParser
import Foundation
import ZTPOCR

struct OCRCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ocr",
        abstract: "Local on-device OCR for images, PDFs and screen captures (Vision)",
        subcommands: [
            OCRImageCmd.self, OCRPDFCmd.self, OCRScreenCmd.self, OCRLanguagesCmd.self,
        ]
    )
}

struct OCRImageCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "image", abstract: "OCR an image file")
    @Option(name: .long, help: "Image file path") var input: String
    @Option(name: .long, help: "Comma-separated recognition languages, e.g. en,fr") var languages: String?
    @Option(name: .long, help: "Write extracted text to this file") var output: String?
    @Flag(name: .long, help: "Fast (lower accuracy) recognition") var fast = false
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let langs = ocrLangs(languages)
        let r = try OCREngine.recognizeImage(path: input, languages: langs, fast: fast)
        if let out = output { try r.text.write(toFile: (out as NSString).expandingTildeInPath, atomically: true, encoding: .utf8) }
        if json {
            ocrPJ(["ok": true, "tool": "ztp-ocr", "command": "image", "source": input,
                   "text": r.text, "char_count": r.text.count, "line_count": r.lines.count] as [String: Any])
        } else { print(r.text) }
    }
}

struct OCRPDFCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pdf", abstract: "OCR a PDF (rasterizes each page)")
    @Option(name: .long, help: "PDF file path") var input: String
    @Option(name: .long, help: "Page range, e.g. 1-3 or 1,2,5 (default all)") var pages: String?
    @Option(name: .long, help: "Rasterization DPI (default 200)") var dpi: Int = 200
    @Option(name: .long, help: "Comma-separated recognition languages") var languages: String?
    @Option(name: .long, help: "Write extracted text to this file") var output: String?
    @Flag(name: .long, help: "Fast (lower accuracy) recognition") var fast = false
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let langs = ocrLangs(languages)
        let idx = PDFRasterizer.parsePageRange(pages)
        let rendered = try PDFRasterizer.pageImages(path: input, pageIndices: idx, dpi: Double(dpi))
        var texts: [String] = []
        var totalLines = 0
        for (_, image) in rendered {
            let r = try OCREngine.recognize(cgImage: image, languages: langs, fast: fast)
            texts.append(r.text); totalLines += r.lines.count
        }
        let combined = texts.joined(separator: "\n\n")
        if let out = output { try combined.write(toFile: (out as NSString).expandingTildeInPath, atomically: true, encoding: .utf8) }
        if json {
            ocrPJ(["ok": true, "tool": "ztp-ocr", "command": "pdf", "source": input,
                   "text": combined, "char_count": combined.count, "page_count": rendered.count, "line_count": totalLines] as [String: Any])
        } else { print(combined) }
    }
}

struct OCRScreenCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screen", abstract: "Capture the screen and OCR it")
    @Option(name: .long, help: "Comma-separated recognition languages") var languages: String?
    @Option(name: .long, help: "Write extracted text to this file") var output: String?
    @Flag(name: .long, help: "Fast (lower accuracy) recognition") var fast = false
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let r = try OCREngine.recognizeScreen(languages: ocrLangs(languages), fast: fast)
        if let out = output { try r.text.write(toFile: (out as NSString).expandingTildeInPath, atomically: true, encoding: .utf8) }
        if json {
            ocrPJ(["ok": true, "tool": "ztp-ocr", "command": "screen",
                   "text": r.text, "char_count": r.text.count, "line_count": r.lines.count] as [String: Any])
        } else { print(r.text) }
    }
}

struct OCRLanguagesCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "languages", abstract: "List supported recognition languages")
    @Flag(name: .long, help: "Fast model languages") var fast = false
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() {
        let langs = OCREngine.supportedLanguages(fast: fast)
        if json { ocrPJ(["ok": true, "tool": "ztp-ocr", "command": "languages", "languages": langs, "count": langs.count] as [String: Any]) }
        else { for l in langs { print(l) } }
    }
}

// MARK: - File-private helpers

private func ocrLangs(_ raw: String?) -> [String] {
    guard let raw, !raw.isEmpty else { return [] }
    return raw.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0) }
}

private func ocrPJ(_ d: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: data, encoding: .utf8) { print(s) }
}

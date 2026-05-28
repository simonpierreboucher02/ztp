import ArgumentParser
import Foundation
import ZTPBrowser

struct BrowserCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "browser",
        abstract: "Native browser automation and web extraction",
        subcommands: [
            BrowserScreenshotCommand.self,
            BrowserPDFCommand.self,
            BrowserHTMLCommand.self,
            BrowserTextCommand.self,
            BrowserLinksCommand.self,
            BrowserMetadataCommand.self,
            BrowserInspectCommand.self,
            BrowserOpenCommand.self,
            BrowserValidateSpecCommand.self,
            BrowserRunCommand.self,
            BrowserSafariCommand.self,
        ]
    )
}

struct BrowserScreenshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture a webpage screenshot")
    @Argument(help: "URL to capture") var url: String
    @Option(name: .long, help: "Output PNG file") var output: String
    @Option(name: .long, help: "Viewport width") var width: Int = 1440
    @Option(name: .long, help: "Viewport height") var height: Int = 900
    @Option(name: .long, help: "Timeout in ms") var timeoutMs: Int = 10000
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        let urlVal = URLValidator.validate(urlString: url)
        guard urlVal.valid else { printErrors(urlVal.errors.map { $0.message }); throw ExitCode.failure }
        guard let parsed = URL(string: url) else { throw ExitCode.failure }

        let start = ContinuousClock.now
        let vp = Viewport(width: width, height: height)
        let result = try await BrowserEngine.execute(action: .screenshot, url: parsed, viewport: vp, timeoutMs: timeoutMs, output: output)

        if let data = result.data {
            let tmp = output + ".tmp"
            try data.write(to: URL(fileURLWithPath: tmp))
            let fm = FileManager.default
            if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
            try fm.moveItem(atPath: tmp, toPath: output)
        }

        let elapsed = ems(from: start)
        if json {
            pj(["ok": true, "tool": "ztp-browser", "command": "screenshot", "url": url, "output": output,
                "metrics": ["duration_ms": elapsed, "width": width, "height": height] as [String: Any]] as [String: Any])
        } else {
            print("Screenshot saved to \(output) (\(elapsed) ms)")
        }
    }
}

struct BrowserPDFCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pdf", abstract: "Export webpage as PDF")
    @Argument(help: "URL") var url: String
    @Option(name: .long, help: "Output PDF file") var output: String
    @Option(name: .long, help: "Timeout in ms") var timeoutMs: Int = 10000
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let start = ContinuousClock.now
        let result = try await BrowserEngine.execute(action: .pdf, url: parsed, viewport: .desktop, timeoutMs: timeoutMs, output: output)
        if let data = result.data { try atomicWrite(data, to: output) }
        let elapsed = ems(from: start)
        if json {
            pj(["ok": true, "tool": "ztp-browser", "command": "pdf", "url": url, "output": output,
                "metrics": ["duration_ms": elapsed, "file_size_bytes": result.data?.count ?? 0] as [String: Any]] as [String: Any])
        } else { print("PDF saved to \(output) (\(elapsed) ms)") }
    }
}

struct BrowserHTMLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "html", abstract: "Fetch page HTML")
    @Argument(help: "URL") var url: String
    @Option(name: .long, help: "Output HTML file") var output: String?
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let start = ContinuousClock.now
        let result = try await BrowserEngine.execute(action: .html, url: parsed, viewport: .desktop, timeoutMs: 10000, output: nil)
        if let out = output, let text = result.text { try atomicWrite(Data(text.utf8), to: out) }
        let elapsed = ems(from: start)
        if json {
            pj(["ok": true, "tool": "ztp-browser", "command": "html", "url": url,
                "metrics": ["duration_ms": elapsed, "chars": result.text?.count ?? 0] as [String: Any]] as [String: Any])
        } else if output == nil, let text = result.text {
            print(text)
        } else { print("HTML saved to \(output!) (\(elapsed) ms)") }
    }
}

struct BrowserTextCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "text", abstract: "Extract page text")
    @Argument(help: "URL") var url: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let start = ContinuousClock.now
        let result = try await BrowserEngine.execute(action: .text, url: parsed, viewport: .desktop, timeoutMs: 10000, output: nil)
        let elapsed = ems(from: start)
        if json {
            pj(["ok": true, "tool": "ztp-browser", "command": "text", "url": url,
                "result": ["text": result.text ?? "", "chars": result.text?.count ?? 0] as [String: Any],
                "metrics": ["duration_ms": elapsed] as [String: Any]] as [String: Any])
        } else { print(result.text ?? "") }
    }
}

struct BrowserLinksCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "links", abstract: "Extract page links")
    @Argument(help: "URL") var url: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let start = ContinuousClock.now
        let result = try await BrowserEngine.execute(action: .links, url: parsed, viewport: .desktop, timeoutMs: 10000, output: nil)
        let elapsed = ems(from: start)
        if json {
            let links = (result.links ?? []).prefix(100).map { ["text": $0.text, "href": $0.href, "external": $0.isExternal] as [String: Any] }
            pj(["ok": true, "tool": "ztp-browser", "command": "links", "url": url,
                "links": Array(links), "count": result.links?.count ?? 0,
                "metrics": ["duration_ms": elapsed] as [String: Any]] as [String: Any])
        } else {
            for l in result.links ?? [] { print("\(l.text.isEmpty ? "(no text)" : l.text) → \(l.href)") }
        }
    }
}

struct BrowserMetadataCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "metadata", abstract: "Extract page metadata")
    @Argument(help: "URL") var url: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let start = ContinuousClock.now
        let result = try await BrowserEngine.execute(action: .metadata, url: parsed, viewport: .desktop, timeoutMs: 10000, output: nil)
        let elapsed = ems(from: start)
        guard let meta = result.metadata else { print("No metadata"); throw ExitCode.failure }
        if json {
            var doc: [String: Any] = ["link_count": meta.linkCount, "text_length": meta.textLength]
            if let t = meta.title { doc["title"] = t }
            if let d = meta.description { doc["description"] = d }
            if let c = meta.canonicalURL { doc["canonical"] = c }
            if let og = meta.ogTitle { doc["og_title"] = og }
            let headings = meta.headings.map { ["level": $0.level, "text": $0.text] as [String: Any] }
            doc["headings"] = headings
            pj(["ok": true, "tool": "ztp-browser", "command": "metadata", "url": url,
                "metadata": doc, "metrics": ["duration_ms": elapsed] as [String: Any]] as [String: Any])
        } else {
            if let t = meta.title { print("Title: \(t)") }
            if let d = meta.description { print("Description: \(d)") }
            print("Links: \(meta.linkCount)")
            print("Headings: \(meta.headings.count)")
        }
    }
}

struct BrowserInspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Full page inspection")
    @Argument(help: "URL") var url: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        guard URLValidator.validate(urlString: url).valid, let parsed = URL(string: url) else {
            print("Invalid URL"); throw ExitCode.failure
        }
        let result = try await BrowserEngine.execute(action: .inspect, url: parsed, viewport: .desktop, timeoutMs: 10000, output: nil)
        guard let meta = result.metadata else { throw ExitCode.failure }
        if json {
            var doc: [String: Any] = ["link_count": meta.linkCount, "text_length": meta.textLength]
            if let t = meta.title { doc["title"] = t }
            if let d = meta.description { doc["description"] = d }
            pj(["ok": true, "tool": "ztp-browser", "command": "inspect", "url": url, "page": doc] as [String: Any])
        } else {
            if let t = meta.title { print("Title: \(t)") }
            print("Links: \(meta.linkCount), Text: \(meta.textLength) chars, Headings: \(meta.headings.count)")
        }
    }
}

struct BrowserOpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open", abstract: "Open URL in Safari")
    @Argument(help: "URL") var url: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let result = try SafariBridge.openURL(url)
        if json {
            pj(["ok": result.success, "tool": "ztp-browser", "command": "open", "url": url, "message": result.message] as [String: Any])
        } else { print(result.message) }
        if !result.success { throw ExitCode.failure }
    }
}

struct BrowserValidateSpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-spec", abstract: "Validate a browser task spec")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = BrowserSpecValidator.validate(jsonData: data)
        if json {
            let errors = result.errors.map { ["code": $0.code, "message": $0.message] as [String: String] }
            pj(["ok": result.valid, "tool": "ztp-browser", "command": "validate-spec", "valid": result.valid, "errors": errors] as [String: Any])
        } else if result.valid { print("Spec is valid.") }
        else { for e in result.errors { print("  [\(e.code)] \(e.message)") }; throw ExitCode.failure }
    }
}

struct BrowserRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Execute a browser task from spec")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(BrowserSpec.self, from: data)
        let start = ContinuousClock.now
        let result = try await BrowserEngine.executeSpec(spec)
        let elapsed = ems(from: start)
        if json {
            pj(["ok": true, "tool": "ztp-browser", "command": "run", "action": spec.task.action,
                "url": spec.task.url, "metrics": ["duration_ms": elapsed] as [String: Any]] as [String: Any])
        } else { print("Task \(spec.task.action) completed (\(elapsed) ms)") }
    }
}

struct BrowserSafariCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "safari", abstract: "Safari bridge commands",
        subcommands: [SafariURLCmd.self, SafariTitleCmd.self]
    )
}

struct SafariURLCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current-url", abstract: "Get Safari current URL")
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try SafariBridge.currentURL()
        if json { pj(["ok": r.success, "tool": "ztp-browser", "url": r.data ?? ""] as [String: Any]) }
        else { print(r.data ?? r.message) }
    }
}

struct SafariTitleCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "title", abstract: "Get Safari current title")
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try SafariBridge.currentTitle()
        if json { pj(["ok": r.success, "tool": "ztp-browser", "title": r.data ?? ""] as [String: Any]) }
        else { print(r.data ?? r.message) }
    }
}

private func pj(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) { print(str) }
}
private func ems(from start: ContinuousClock.Instant) -> Int64 {
    let e = start.duration(to: .now)
    return e.components.seconds * 1000 + e.components.attoseconds / 1_000_000_000_000_000
}
private func printErrors(_ msgs: [String]) { for m in msgs { print("Error: \(m)") } }
private func atomicWrite(_ data: Data, to path: String) throws {
    let tmp = path + ".tmp"
    try data.write(to: URL(fileURLWithPath: tmp))
    let fm = FileManager.default
    if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
    try fm.moveItem(atPath: tmp, toPath: path)
}

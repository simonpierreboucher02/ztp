import Foundation

public struct BrowserEngine: Sendable {

    public enum OutputFormat: String, Sendable {
        case png, pdf, html, json
    }

    public struct BrowserResult: Sendable {
        public let data: Data?
        public let text: String?
        public let metadata: PageMetadata?
        public let links: [LinkInfo]?
        public let durationMs: Int64

        public init(data: Data?, text: String?, metadata: PageMetadata?, links: [LinkInfo]?, durationMs: Int64) {
            self.data = data
            self.text = text
            self.metadata = metadata
            self.links = links
            self.durationMs = durationMs
        }
    }

    // MARK: - Execute

    public static func execute(
        action: BrowserAction,
        url: URL,
        viewport: Viewport = .desktop,
        timeoutMs: Int = 10000,
        output: String? = nil
    ) async throws -> BrowserResult {
        let start = ContinuousClock.now

        switch action {
        case .screenshot:
            let pngData = try await WebKitRenderer.screenshot(url: url, viewport: viewport, timeoutMs: timeoutMs)

            if let outputPath = output {
                try atomicWrite(data: pngData, to: outputPath)
            }

            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: pngData, text: nil, metadata: nil, links: nil, durationMs: elapsed)

        case .pdf:
            let pdfData = try await WebKitRenderer.pdf(url: url, viewport: viewport, timeoutMs: timeoutMs)

            if let outputPath = output {
                try atomicWrite(data: pdfData, to: outputPath)
            }

            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: pdfData, text: nil, metadata: nil, links: nil, durationMs: elapsed)

        case .html:
            let fetchResult = try await HTTPFetcher.fetch(url: url, timeoutMs: timeoutMs)
            let htmlData = Data(fetchResult.html.utf8)

            if let outputPath = output {
                try atomicWrite(data: htmlData, to: outputPath)
            }

            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: htmlData, text: fetchResult.html, metadata: nil, links: nil, durationMs: elapsed)

        case .text:
            let fetchResult = try await HTTPFetcher.fetch(url: url, timeoutMs: timeoutMs)
            let plainText = HTMLContentParser.extractText(from: fetchResult.html)
            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: nil, text: plainText, metadata: nil, links: nil, durationMs: elapsed)

        case .links:
            let fetchResult = try await HTTPFetcher.fetch(url: url, timeoutMs: timeoutMs)
            let links = HTMLContentParser.extractLinks(from: fetchResult.html, baseURL: fetchResult.finalURL)
            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: nil, text: nil, metadata: nil, links: links, durationMs: elapsed)

        case .metadata:
            let fetchResult = try await HTTPFetcher.fetch(url: url, timeoutMs: timeoutMs)
            let meta = HTMLContentParser.extractMetadata(from: fetchResult.html, baseURL: fetchResult.finalURL)
            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: nil, text: nil, metadata: meta, links: nil, durationMs: elapsed)

        case .inspect:
            let fetchResult = try await HTTPFetcher.fetch(url: url, timeoutMs: timeoutMs)
            let meta = HTMLContentParser.extractMetadata(from: fetchResult.html, baseURL: fetchResult.finalURL)
            let links = HTMLContentParser.extractLinks(from: fetchResult.html, baseURL: fetchResult.finalURL)
            let plainText = HTMLContentParser.extractText(from: fetchResult.html)
            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: nil, text: plainText, metadata: meta, links: links, durationMs: elapsed)

        case .open:
            let _ = try SafariBridge.openURL(url.absoluteString)
            let elapsed = elapsedMs(from: start)
            return BrowserResult(data: nil, text: "Opened \(url.absoluteString) in Safari", metadata: nil, links: nil, durationMs: elapsed)
        }
    }

    // MARK: - Spec Execution

    public static func executeSpec(_ spec: BrowserSpec) async throws -> BrowserResult {
        let validation = BrowserSpecValidator.validate(spec: spec)
        guard validation.valid else {
            let messages = validation.errors.map { $0.message }
            throw BrowserEngineError.specValidationFailed(messages.joined(separator: "; "))
        }

        guard let action = BrowserAction(rawValue: spec.task.action.lowercased()) else {
            throw BrowserEngineError.invalidAction(spec.task.action)
        }

        guard let url = URL(string: spec.task.url) else {
            throw BrowserEngineError.invalidURL(spec.task.url)
        }

        let viewport: Viewport
        if let vc = spec.task.viewport {
            viewport = Viewport(
                width: vc.width ?? 1440,
                height: vc.height ?? 900,
                scale: vc.scale ?? 2
            )
        } else {
            viewport = .desktop
        }

        let timeoutMs = spec.task.wait?.timeoutMs ?? 10000

        return try await execute(
            action: action,
            url: url,
            viewport: viewport,
            timeoutMs: timeoutMs,
            output: spec.task.output
        )
    }

    // MARK: - Helpers

    private static func atomicWrite(data: Data, to path: String) throws {
        let tempPath = path + ".tmp"
        try data.write(to: URL(fileURLWithPath: tempPath))

        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try fm.removeItem(atPath: path)
        }
        try fm.moveItem(atPath: tempPath, toPath: path)
    }

    private static func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

// MARK: - Engine Errors

public enum BrowserEngineError: Error, Sendable {
    case invalidAction(String)
    case invalidURL(String)
    case specValidationFailed(String)
}

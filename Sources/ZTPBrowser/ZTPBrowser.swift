import Foundation
import ZTPCore
import ZTPProtocols

public struct ZTPBrowserTool: ZTPTool {
    public let manifest = ToolManifest(
        name: "ztp-browser",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "browser.open",
            "browser.screenshot",
            "browser.pdf",
            "browser.html",
            "browser.text",
            "browser.links",
            "browser.metadata",
            "browser.safari",
        ],
        permissions: ["filesystem": true, "network": true]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified.")
            )
        }

        let start = ContinuousClock.now

        switch command {
        case "screenshot":
            return try await executeAction(.screenshot, input: input, start: start)
        case "pdf":
            return try await executeAction(.pdf, input: input, start: start)
        case "html":
            return try await executeAction(.html, input: input, start: start)
        case "text":
            return try await executeAction(.text, input: input, start: start)
        case "links":
            return try await executeAction(.links, input: input, start: start)
        case "metadata":
            return try await executeAction(.metadata, input: input, start: start)
        case "inspect":
            return try await executeAction(.inspect, input: input, start: start)
        case "open":
            return try await executeAction(.open, input: input, start: start)
        case "safari-url":
            return try executeSafariURL(start: start)
        case "safari-title":
            return try executeSafariTitle(start: start)
        case "validate-spec":
            return try executeValidateSpec(input: input, start: start)
        case "run":
            return try await executeRun(input: input, start: start)
        default:
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
            )
        }
    }

    // MARK: - Action Dispatch

    private func executeAction(
        _ action: BrowserAction,
        input: ToolInput,
        start: ContinuousClock.Instant
    ) async throws -> ToolResult {
        guard let urlString = input.string(for: "url") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_URL", message: "No URL specified.")
            )
        }

        let urlValidation = URLValidator.validate(urlString: urlString)
        let hardErrors = urlValidation.errors.filter { $0.code != "LOCALHOST_WARNING" }
        guard hardErrors.isEmpty, let url = URL(string: urlString) else {
            let msg = urlValidation.errors.map(\.message).joined(separator: "; ")
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "INVALID_URL", message: msg)
            )
        }

        let viewport = buildViewport(from: input)
        let timeoutMs = input.int(for: "timeout_ms") ?? 10000
        let output = input.string(for: "output")

        do {
            let result = try await BrowserEngine.execute(
                action: action,
                url: url,
                viewport: viewport,
                timeoutMs: timeoutMs,
                output: output
            )

            return buildSuccessResult(command: action.rawValue, result: result, output: output, start: start)
        } catch {
            let elapsed = elapsedMs(from: start)
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: elapsed,
                error: ToolErrorInfo(code: "EXECUTION_FAILED", message: error.localizedDescription)
            )
        }
    }

    // MARK: - Safari Commands

    private func executeSafariURL(start: ContinuousClock.Instant) throws -> ToolResult {
        do {
            let result = try SafariBridge.currentURL()
            let elapsed = elapsedMs(from: start)
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("safari-url"),
                "url": .string(result.data ?? ""),
            ])
        } catch {
            let elapsed = elapsedMs(from: start)
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: elapsed,
                error: ToolErrorInfo(code: "SAFARI_ERROR", message: error.localizedDescription)
            )
        }
    }

    private func executeSafariTitle(start: ContinuousClock.Instant) throws -> ToolResult {
        do {
            let result = try SafariBridge.currentTitle()
            let elapsed = elapsedMs(from: start)
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("safari-title"),
                "title": .string(result.data ?? ""),
            ])
        } catch {
            let elapsed = elapsedMs(from: start)
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: elapsed,
                error: ToolErrorInfo(code: "SAFARI_ERROR", message: error.localizedDescription)
            )
        }
    }

    // MARK: - Spec Validation

    private func executeValidateSpec(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified.")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let validation = BrowserSpecValidator.validate(jsonData: specData)
        let elapsed = elapsedMs(from: start)

        if validation.valid {
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("validate-spec"),
                "valid": .bool(true),
            ])
        } else {
            let errorMessages: [JSONValue] = validation.errors.map { .string($0.message) }
            return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
                "command": .string("validate-spec"),
                "valid": .bool(false),
                "error_count": .int(validation.errors.count),
                "errors": .array(errorMessages),
            ])
        }
    }

    // MARK: - Spec Run

    private func executeRun(input: ToolInput, start: ContinuousClock.Instant) async throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified.")
            )
        }

        let specData: Data
        do {
            specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        } catch {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "FILE_READ_ERROR", message: "Could not read spec file: \(error.localizedDescription)")
            )
        }

        let spec: BrowserSpec
        do {
            spec = try JSONDecoder().decode(BrowserSpec.self, from: specData)
        } catch {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "INVALID_JSON", message: "Failed to decode BrowserSpec: \(error.localizedDescription)")
            )
        }

        do {
            let result = try await BrowserEngine.executeSpec(spec)
            return buildSuccessResult(command: "run", result: result, output: spec.task.output, start: start)
        } catch {
            let elapsed = elapsedMs(from: start)
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: elapsed,
                error: ToolErrorInfo(code: "EXECUTION_FAILED", message: error.localizedDescription)
            )
        }
    }

    // MARK: - Helpers

    private func buildViewport(from input: ToolInput) -> Viewport {
        let width = input.int(for: "width") ?? 1440
        let height = input.int(for: "height") ?? 900
        let scale = input.int(for: "scale") ?? 2
        return Viewport(width: width, height: height, scale: scale)
    }

    private func buildSuccessResult(
        command: String,
        result: BrowserEngine.BrowserResult,
        output: String?,
        start: ContinuousClock.Instant
    ) -> ToolResult {
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string(command),
            "duration_ms": .int(Int(result.durationMs)),
        ]

        if let outputPath = output {
            data["output"] = .string(outputPath)
        }

        if let binaryData = result.data {
            data["size_bytes"] = .int(binaryData.count)
        }

        if let text = result.text {
            data["text"] = .string(text)
            data["text_length"] = .int(text.count)
        }

        if let meta = result.metadata {
            var metaDict: [String: JSONValue] = [
                "link_count": .int(meta.linkCount),
                "text_length": .int(meta.textLength),
                "heading_count": .int(meta.headings.count),
            ]
            if let title = meta.title { metaDict["title"] = .string(title) }
            if let desc = meta.description { metaDict["description"] = .string(desc) }
            if let canonical = meta.canonicalURL { metaDict["canonical_url"] = .string(canonical) }
            if let ogTitle = meta.ogTitle { metaDict["og_title"] = .string(ogTitle) }
            if let ogDesc = meta.ogDescription { metaDict["og_description"] = .string(ogDesc) }
            if let ogImage = meta.ogImage { metaDict["og_image"] = .string(ogImage) }
            data["metadata"] = .object(metaDict)
        }

        if let links = result.links {
            let linkValues: [JSONValue] = links.prefix(100).map { link in
                .object([
                    "text": .string(link.text),
                    "href": .string(link.href),
                    "is_external": .bool(link.isExternal),
                ])
            }
            data["links"] = .array(linkValues)
            data["link_count"] = .int(links.count)
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

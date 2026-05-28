import Foundation
import ZTPCore
import ZTPProtocols

public struct ZTPDocxTool: ZTPTool {
    public let manifest = ToolManifest(
        name: "ztp-docx",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: ["docx.create", "docx.inspect", "docx.validate", "docx.tables", "docx.images"],
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
            return try executeBuild(input: input, start: start)
        case "validate-spec":
            return try executeValidateSpec(input: input, start: start)
        case "validate":
            return try executeValidate(input: input, start: start)
        case "inspect":
            return try executeInspect(input: input, start: start)
        default:
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
            )
        }
    }

    private func executeBuild(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No input spec file"))
        }
        guard let outputPath = input.string(for: "output") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path"))
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(DocumentSpec.self, from: specData)
        let document = try spec.toDocument()
        let styleMap = spec.toStyleMap()

        var registry = DocxStyleRegistry()
        for (name, style) in styleMap {
            registry.register(name: name, style: style)
        }

        let basePath = (specPath as NSString).deletingLastPathComponent
        let docxData = try DocxPackager.package(document: document, styleRegistry: registry, basePath: basePath)

        let tempPath = outputPath + ".tmp"
        try docxData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
        try fm.moveItem(atPath: tempPath, toPath: outputPath)

        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("build"),
            "output": .string(outputPath),
            "sections": .int(document.sections.count),
            "paragraphs": .int(document.totalParagraphs),
            "tables": .int(document.totalTables),
            "images": .int(document.totalImages),
            "file_size_bytes": .int(docxData.count),
        ])
    }

    private func executeValidateSpec(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file"))
        }
        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let result = DocxSpecValidator.validate(jsonData: specData)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("validate-spec"),
            "valid": .bool(result.valid),
            "error_count": .int(result.errors.count),
        ])
    }

    private func executeValidate(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let filePath = input.string(for: "input") else {
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No docx file"))
        }
        let result = try DocxValidator.validate(at: filePath)
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
            return ToolResult.failure(tool: manifest.name, error: ToolErrorInfo(code: "MISSING_INPUT", message: "No docx file"))
        }
        let info = try DocxInspector.inspect(at: filePath)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("inspect"),
            "paragraphs": .int(info.paragraphs),
            "tables": .int(info.tables),
            "images": .int(info.images),
            "headings": .int(info.headings),
        ])
    }

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

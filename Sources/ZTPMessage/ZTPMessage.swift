import Foundation
import ZTPCore
import ZTPProtocols

public struct ZTPMessageTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-message",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "message.validate",
            "message.preview",
            "message.draft",
            "message.send",
            "message.imessage",
            "message.sms",
        ],
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
        case "validate":
            return try executeValidate(input: input, start: start)
        case "preview":
            return try executePreview(input: input, start: start)
        case "draft":
            return try executeDraft(input: input, start: start)
        case "send":
            return try executeSend(input: input, start: start)
        case "apple-draft":
            return try executeAppleDraft(input: input, start: start)
        case "inspect":
            return try executeInspect(input: input, start: start)
        case "templates":
            return executeTemplates(start: start)
        default:
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
            )
        }
    }

    // MARK: - validate

    private func executeValidate(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let result = MessageValidator.validate(jsonData: specData)
        let elapsed = elapsedMs(from: start)

        var data: [String: JSONValue] = [
            "command": .string("validate"),
            "valid": .bool(result.valid),
            "error_count": .int(result.errors.count),
            "warning_count": .int(result.warnings.count),
        ]

        if !result.errors.isEmpty {
            data["errors"] = .array(result.errors.map { error in
                var obj: [String: JSONValue] = [
                    "code": .string(error.code),
                    "message": .string(error.message),
                ]
                if let path = error.path {
                    obj["path"] = .string(path)
                }
                if let hint = error.hint {
                    obj["hint"] = .string(hint)
                }
                return .object(obj)
            })
        }

        if !result.warnings.isEmpty {
            data["warnings"] = .array(result.warnings.map { warning in
                .object([
                    "code": .string(warning.code),
                    "message": .string(warning.message),
                ])
            })
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - preview

    private func executePreview(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: specData)
        let message = try spec.toMessage()
        let elapsed = elapsedMs(from: start)

        let recipientList: [JSONValue] = message.to.map { r in
            .object([
                "name": r.name.map { .string($0) } ?? .null,
                "address": .string(r.address),
            ])
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("preview"),
            "channel": .string(message.channel.rawValue),
            "recipients": .array(recipientList),
            "recipient_count": .int(message.recipientCount),
            "body": .string(message.body.content),
            "body_type": .string(message.body.type.rawValue),
            "character_count": .int(message.characterCount),
        ])
    }

    // MARK: - draft

    private func executeDraft(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }
        guard let outputPath = input.string(for: "output") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path specified")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: specData)
        let message = try spec.toMessage()

        let draftJSON = try DraftGenerator.generateJSON(message: message)

        // Atomic write
        let tempPath = outputPath + ".tmp"
        try draftJSON.write(to: URL(fileURLWithPath: tempPath))

        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        try fm.moveItem(atPath: tempPath, toPath: outputPath)

        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("draft"),
            "input": .string(specPath),
            "output": .string(outputPath),
            "channel": .string(message.channel.rawValue),
            "recipient_count": .int(message.recipientCount),
            "character_count": .int(message.characterCount),
            "file_size_bytes": .int(draftJSON.count),
        ])
    }

    // MARK: - send

    private func executeSend(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        let confirmed = input.bool(for: "confirmed") ?? false
        guard confirmed else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(
                    code: "NOT_CONFIRMED",
                    message: "Send requires confirmed=true in input parameters"
                )
            )
        }

        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: specData)
        let message = try spec.toMessage()

        let sendResult = try AppleMessagesSender.send(message: message, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("send"),
            "success": .bool(sendResult.success),
            "channel": .string(sendResult.channel),
            "recipients_sent": .int(sendResult.recipientsSent),
            "character_count": .int(message.characterCount),
            "message": .string(sendResult.message),
        ])
    }

    // MARK: - apple-draft

    private func executeAppleDraft(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: specData)
        let message = try spec.toMessage()

        let draftResult = try AppleMessagesSender.createDraft(message: message)
        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apple-draft"),
            "success": .bool(draftResult.success),
            "channel": .string(draftResult.channel),
            "recipient_count": .int(message.recipientCount),
            "character_count": .int(message.characterCount),
            "message": .string(draftResult.message),
        ])
    }

    // MARK: - inspect

    private func executeInspect(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let filePath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No draft file specified")
            )
        }

        let info = try DraftInspector.inspect(at: filePath)
        let elapsed = elapsedMs(from: start)

        var data: [String: JSONValue] = [
            "command": .string("inspect"),
            "recipients": .array(info.recipients.map { .string($0) }),
            "character_count": .int(info.characterCount),
        ]

        if let channel = info.channel {
            data["channel"] = .string(channel)
        }
        if let body = info.body {
            data["body"] = .string(body)
        }
        if let createdAt = info.createdAt {
            data["created_at"] = .string(createdAt)
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - templates

    private func executeTemplates(start: ContinuousClock.Instant) -> ToolResult {
        let templates = MessageTemplateEngine.list()
        let elapsed = elapsedMs(from: start)

        let templateList: [JSONValue] = templates.map { tmpl in
            .object([
                "name": .string(tmpl.name),
                "pattern": .string(tmpl.pattern),
                "description": .string(tmpl.description),
            ])
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("templates"),
            "count": .int(templates.count),
            "templates": .array(templateList),
        ])
    }

    // MARK: - Helpers

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

import Foundation
import ZTPCore
import ZTPProtocols

public struct ZTPMailTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-mail",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "mail.validate",
            "mail.preview",
            "mail.draft",
            "mail.send",
            "mail.apple-draft",
            "mail.inspect",
        ],
        permissions: ["filesystem": true, "network": true]
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
            return try executeValidate(input: input, context: context, start: start)
        case "preview":
            return try executePreview(input: input, context: context, start: start)
        case "draft":
            return try executeDraft(input: input, context: context, start: start)
        case "send":
            return try await executeSend(input: input, context: context, start: start)
        case "apple-draft":
            return try executeAppleDraft(input: input, context: context, start: start)
        case "inspect":
            return try executeInspect(input: input, start: start)
        default:
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
            )
        }
    }

    // MARK: - validate

    private func executeValidate(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let basePath = input.string(for: "base_path")
        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let result = MailValidator.validate(jsonData: specData, basePath: basePath)
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

    private func executePreview(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) throws -> ToolResult {
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
        let spec = try MailSpec.decode(from: specData)
        let message = try spec.toMessage()

        let rendered = HTMLMailRenderer.render(body: message.body, signature: message.signature)

        let tempPath = outputPath + ".tmp"
        try Data(rendered.utf8).write(to: URL(fileURLWithPath: tempPath))

        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        try fm.moveItem(atPath: tempPath, toPath: outputPath)

        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("preview"),
            "input": .string(specPath),
            "output": .string(outputPath),
            "body_type": .string(message.body.type.rawValue),
            "body_chars": .int(message.bodyCharCount),
            "output_size_bytes": .int(rendered.utf8.count),
        ])
    }

    // MARK: - draft

    private func executeDraft(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) throws -> ToolResult {
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

        let basePath = input.string(for: "base_path")
        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try MailSpec.decode(from: specData)
        let message = try spec.toMessage()

        let emlData = try EMLGenerator.generate(message: message, basePath: basePath)

        // Atomic write
        let tempPath = outputPath + ".tmp"
        try emlData.write(to: URL(fileURLWithPath: tempPath))

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
            "recipients": .int(message.recipientCount),
            "attachments": .int(message.attachments.count),
            "body_chars": .int(message.bodyCharCount),
            "file_size_bytes": .int(emlData.count),
        ])
    }

    // MARK: - send

    private func executeSend(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) async throws -> ToolResult {
        // Require explicit confirmation
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

        let profileName = input.string(for: "profile")
        let basePath = input.string(for: "base_path")

        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try MailSpec.decode(from: specData)
        let message = try spec.toMessage()

        // Load SMTP profile
        let profile: SMTPProfile
        if let name = profileName {
            guard let found = try SMTPConfigManager.profile(named: name) else {
                return ToolResult.failure(
                    tool: manifest.name,
                    error: ToolErrorInfo(
                        code: "PROFILE_NOT_FOUND",
                        message: "SMTP profile '\(name)' not found"
                    )
                )
            }
            profile = found
        } else {
            let profiles = try SMTPConfigManager.loadProfiles()
            guard let first = profiles.first else {
                return ToolResult.failure(
                    tool: manifest.name,
                    error: ToolErrorInfo(
                        code: "NO_PROFILES",
                        message: "No SMTP profiles configured. Add profiles to ~/.ztp/mail/profiles.json"
                    )
                )
            }
            profile = first
        }

        // Send via SMTP
        let sendResult = try SMTPSender.send(
            message: message,
            profile: profile,
            confirmed: confirmed,
            basePath: basePath
        )

        let elapsed = elapsedMs(from: start)

        var data: [String: JSONValue] = [
            "command": .string("send"),
            "success": .bool(sendResult.success),
            "recipients": .int(message.recipientCount),
            "attachments": .int(message.attachments.count),
            "body_chars": .int(message.bodyCharCount),
            "profile": .string(profile.name),
            "message": .string(sendResult.message),
        ]

        if let messageId = sendResult.messageId {
            data["message_id"] = .string(messageId)
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - apple-draft

    private func executeAppleDraft(input: ToolInput, context: ToolContext, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let specPath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No spec file specified")
            )
        }

        let basePath = input.string(for: "base_path")
        let specData = try Data(contentsOf: URL(fileURLWithPath: specPath))
        let spec = try MailSpec.decode(from: specData)
        let message = try spec.toMessage()

        let draftResult = try AppleMailDraft.createDraft(message: message, basePath: basePath)

        let elapsed = elapsedMs(from: start)

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apple-draft"),
            "success": .bool(draftResult.success),
            "recipients": .int(message.recipientCount),
            "attachments": .int(message.attachments.count),
            "body_chars": .int(message.bodyCharCount),
            "message": .string(draftResult.message),
        ])
    }

    // MARK: - inspect

    private func executeInspect(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let filePath = input.string(for: "input") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_INPUT", message: "No .eml file specified")
            )
        }

        let info = try EMLInspector.inspect(at: filePath)
        let elapsed = elapsedMs(from: start)

        var data: [String: JSONValue] = [
            "command": .string("inspect"),
            "has_attachments": .bool(info.hasAttachments),
            "attachment_count": .int(info.attachmentNames.count),
            "body_length": .int(info.bodyLength),
        ]

        if let from = info.from {
            data["from"] = .string(from)
        }

        data["to"] = .array(info.to.map { .string($0) })
        data["cc"] = .array(info.cc.map { .string($0) })

        if let subject = info.subject {
            data["subject"] = .string(subject)
        }

        if let date = info.date {
            data["date"] = .string(date)
        }

        if let contentType = info.contentType {
            data["content_type"] = .string(contentType)
        }

        if !info.attachmentNames.isEmpty {
            data["attachment_names"] = .array(info.attachmentNames.map { .string($0) })
        }

        if let preview = info.bodyPreview {
            data["body_preview"] = .string(preview)
        }

        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - Helpers

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

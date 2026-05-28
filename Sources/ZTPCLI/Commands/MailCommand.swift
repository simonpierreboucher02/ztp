import ArgumentParser
import Foundation
import ZTPMail

struct MailCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mail",
        abstract: "Native email drafting and sending",
        subcommands: [
            MailValidateCommand.self,
            MailPreviewCommand.self,
            MailDraftCommand.self,
            MailSendCommand.self,
            MailAppleDraftCommand.self,
            MailInspectCommand.self,
        ]
    )
}

struct MailValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate an email spec")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let basePath = (specFile as NSString).deletingLastPathComponent
        let result = MailValidator.validate(jsonData: specData, basePath: basePath)

        if json {
            let errors = result.errors.map { ["code": $0.code, "message": $0.message, "path": $0.path ?? "", "hint": $0.hint ?? ""] as [String: String] }
            let warnings = result.warnings.map { ["code": $0.code, "message": $0.message] as [String: String] }
            printJSON(["ok": result.valid, "tool": "ztp-mail", "command": "validate", "valid": result.valid, "errors": errors, "warnings": warnings] as [String: Any])
        } else if result.valid {
            print("Email spec is valid.")
            for w in result.warnings { print("  Warning: [\(w.code)] \(w.message)") }
        } else {
            print("Validation failed:")
            for e in result.errors { print("  [\(e.code)] \(e.message)") }
            for w in result.warnings { print("  Warning: [\(w.code)] \(w.message)") }
            throw ExitCode.failure
        }
    }
}

struct MailPreviewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preview", abstract: "Preview email as HTML")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output HTML file")
    var output: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let start = ContinuousClock.now
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MailSpec.self, from: specData)
        let message = try spec.toMessage()

        let html = HTMLMailRenderer.render(body: message.body, signature: message.signature)
        let htmlData = Data(html.utf8)

        let tempPath = output + ".tmp"
        try htmlData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)

        if json {
            printJSON([
                "ok": true, "tool": "ztp-mail", "command": "preview",
                "output": output, "created_files": [output],
                "metrics": ["duration_ms": elapsed, "file_size_bytes": htmlData.count] as [String: Any],
            ] as [String: Any])
        } else {
            print("Preview written to \(output)")
            print("  Size: \(htmlData.count) bytes")
        }
    }
}

struct MailDraftCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "draft", abstract: "Generate .eml draft file")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Option(name: .long, help: "Output .eml file")
    var output: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let start = ContinuousClock.now
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MailSpec.self, from: specData)
        let message = try spec.toMessage()
        let basePath = (specFile as NSString).deletingLastPathComponent

        let emlData = try EMLGenerator.generate(message: message, basePath: basePath)

        let tempPath = output + ".tmp"
        try emlData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = elapsedMs(from: start)

        if json {
            printJSON([
                "ok": true, "tool": "ztp-mail", "command": "draft",
                "output": output, "created_files": [output],
                "metrics": [
                    "duration_ms": elapsed,
                    "recipients": message.recipientCount,
                    "attachments": message.attachments.count,
                    "body_chars": message.bodyCharCount,
                    "file_size_bytes": emlData.count,
                ] as [String: Any],
            ] as [String: Any])
        } else {
            print("Draft written to \(output)")
            print("  Recipients: \(message.recipientCount)")
            print("  Attachments: \(message.attachments.count)")
            print("  Size: \(emlData.count) bytes")
        }
    }
}

struct MailSendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "send", abstract: "Send email via SMTP")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Option(name: .long, help: "SMTP profile name")
    var smtpProfile: String = "default"

    @Flag(name: .long, help: "Confirm sending (required)")
    var confirm = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        guard confirm else {
            if json {
                printJSON([
                    "ok": false, "tool": "ztp-mail", "command": "send",
                    "errors": [["code": "SEND_CONFIRMATION_REQUIRED", "message": "Sending email requires --confirm."] as [String: String]],
                ] as [String: Any])
            } else {
                print("Error: Sending email requires --confirm flag.")
                print("  Use: ztp mail send \(specFile) --confirm")
            }
            throw ExitCode.failure
        }

        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MailSpec.self, from: specData)
        let message = try spec.toMessage()
        let basePath = (specFile as NSString).deletingLastPathComponent

        guard let profile = try SMTPConfigManager.profile(named: smtpProfile) else {
            if json {
                printJSON([
                    "ok": false, "tool": "ztp-mail", "command": "send",
                    "errors": [["code": "PROFILE_NOT_FOUND", "message": "SMTP profile '\(smtpProfile)' not found. Configure in ~/.ztp/mail/profiles.json"] as [String: String]],
                ] as [String: Any])
            } else {
                print("SMTP profile '\(smtpProfile)' not found.")
                print("  Configure in ~/.ztp/mail/profiles.json")
            }
            throw ExitCode.failure
        }

        let result = try SMTPSender.send(message: message, profile: profile, confirmed: true, basePath: basePath)

        if json {
            printJSON([
                "ok": result.success, "tool": "ztp-mail", "command": "send",
                "message": result.message,
                "message_id": result.messageId ?? "",
            ] as [String: Any])
        } else {
            print(result.message)
        }

        if !result.success { throw ExitCode.failure }
    }
}

struct MailAppleDraftCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apple-draft", abstract: "Create draft in Apple Mail")

    @Argument(help: "JSON spec file")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let specData = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MailSpec.self, from: specData)
        let message = try spec.toMessage()
        let basePath = (specFile as NSString).deletingLastPathComponent

        let result = try AppleMailDraft.createDraft(message: message, basePath: basePath)

        if json {
            printJSON(["ok": result.success, "tool": "ztp-mail", "command": "apple-draft", "message": result.message] as [String: Any])
        } else {
            print(result.message)
        }

        if !result.success { throw ExitCode.failure }
    }
}

struct MailInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect an .eml file")

    @Argument(help: "EML file to inspect")
    var emlFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let info = try EMLInspector.inspect(at: emlFile)

        if json {
            var doc: [String: Any] = [
                "to": info.to,
                "cc": info.cc,
                "has_attachments": info.hasAttachments,
                "attachment_names": info.attachmentNames,
                "body_length": info.bodyLength,
            ]
            if let f = info.from { doc["from"] = f }
            if let s = info.subject { doc["subject"] = s }
            if let d = info.date { doc["date"] = d }
            if let p = info.bodyPreview { doc["body_preview"] = p }
            printJSON(["ok": true, "tool": "ztp-mail", "command": "inspect", "email": doc] as [String: Any])
        } else {
            if let f = info.from { print("From: \(f)") }
            print("To: \(info.to.joined(separator: ", "))")
            if !info.cc.isEmpty { print("Cc: \(info.cc.joined(separator: ", "))") }
            if let s = info.subject { print("Subject: \(s)") }
            if let d = info.date { print("Date: \(d)") }
            if info.hasAttachments { print("Attachments: \(info.attachmentNames.joined(separator: ", "))") }
            if let p = info.bodyPreview { print("Preview: \(p.prefix(200))") }
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

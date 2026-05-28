import ArgumentParser
import Foundation
import ZTPMessage

struct MessageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "message",
        abstract: "Native short-message drafting and sending",
        subcommands: [
            MsgValidateCommand.self,
            MsgPreviewCommand.self,
            MsgDraftCommand.self,
            MsgSendCommand.self,
            MsgAppleDraftCommand.self,
            MsgInspectCommand.self,
            MsgTemplatesCommand.self,
        ]
    )
}

struct MsgValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate a message spec")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let result = MessageValidator.validate(jsonData: data)
        if json {
            let errors = result.errors.map { ["code": $0.code, "message": $0.message, "path": $0.path ?? ""] as [String: String] }
            let warnings = result.warnings.map { ["code": $0.code, "message": $0.message] as [String: String] }
            pj(["ok": result.valid, "tool": "ztp-message", "command": "validate", "valid": result.valid, "errors": errors, "warnings": warnings] as [String: Any])
        } else if result.valid {
            print("Message spec is valid.")
            for w in result.warnings { print("  Warning: \(w.message)") }
        } else {
            print("Validation failed:")
            for e in result.errors { print("  [\(e.code)] \(e.message)") }
            throw ExitCode.failure
        }
    }
}

struct MsgPreviewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preview", abstract: "Preview a message")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: data)
        let msg = try spec.toMessage()
        let recipients = msg.to.map(\.displayName)

        if json {
            pj([
                "ok": true, "tool": "ztp-message", "command": "preview",
                "preview": [
                    "channel": msg.channel.rawValue,
                    "recipients": recipients,
                    "body": msg.body.content,
                    "characters": msg.characterCount,
                ] as [String: Any],
            ] as [String: Any])
        } else {
            print("Channel: \(msg.channel.rawValue)")
            print("To: \(recipients.joined(separator: ", "))")
            print("Body: \(msg.body.content)")
            print("Characters: \(msg.characterCount)")
        }
    }
}

struct MsgDraftCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "draft", abstract: "Generate a draft message file")
    @Argument(help: "JSON spec file") var specFile: String
    @Option(name: .long, help: "Output draft file") var output: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let start = ContinuousClock.now
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: data)
        let msg = try spec.toMessage()
        let draftData = try DraftGenerator.generateJSON(message: msg)

        let tempPath = output + ".tmp"
        try draftData.write(to: URL(fileURLWithPath: tempPath))
        let fm = FileManager.default
        if fm.fileExists(atPath: output) { try fm.removeItem(atPath: output) }
        try fm.moveItem(atPath: tempPath, toPath: output)

        let elapsed = ems(from: start)
        if json {
            pj([
                "ok": true, "tool": "ztp-message", "command": "draft",
                "output": output, "created_files": [output],
                "metrics": ["duration_ms": elapsed, "recipients": msg.recipientCount, "characters": msg.characterCount] as [String: Any],
            ] as [String: Any])
        } else {
            print("Draft written to \(output)")
            print("  Recipients: \(msg.recipientCount)")
            print("  Characters: \(msg.characterCount)")
        }
    }
}

struct MsgSendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "send", abstract: "Send a message via Messages.app")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Confirm sending (required)") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        guard confirm else {
            if json {
                pj(["ok": false, "tool": "ztp-message", "command": "send",
                    "errors": [["code": "SEND_CONFIRMATION_REQUIRED", "message": "Sending requires --confirm.", "hint": "Run with --confirm only after user explicitly approves."] as [String: String]]] as [String: Any])
            } else {
                print("Error: Sending requires --confirm flag.")
            }
            throw ExitCode.failure
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: data)
        let msg = try spec.toMessage()
        let result = try AppleMessagesSender.send(message: msg, confirmed: true)

        if json {
            pj(["ok": result.success, "tool": "ztp-message", "command": "send",
                "channel": result.channel, "recipients": result.recipientsSent,
                "message": result.message] as [String: Any])
        } else {
            print(result.message)
        }
        if !result.success { throw ExitCode.failure }
    }
}

struct MsgAppleDraftCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apple-draft", abstract: "Open Messages.app to compose")
    @Argument(help: "JSON spec file") var specFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: specFile))
        let spec = try JSONDecoder().decode(MessageSpec.self, from: data)
        let msg = try spec.toMessage()
        let result = try AppleMessagesSender.createDraft(message: msg)

        if json {
            pj(["ok": result.success, "tool": "ztp-message", "command": "apple-draft",
                "message": result.message] as [String: Any])
        } else {
            print(result.message)
        }
        if !result.success { throw ExitCode.failure }
    }
}

struct MsgInspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a draft message file")
    @Argument(help: "Draft JSON file") var draftFile: String
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let info = try DraftInspector.inspect(at: draftFile)

        if json {
            var doc: [String: Any] = ["recipients": info.recipients, "characterCount": info.characterCount]
            if let c = info.channel { doc["channel"] = c }
            if let b = info.body { doc["body"] = b }
            if let d = info.createdAt { doc["created_at"] = d }
            pj(["ok": true, "tool": "ztp-message", "command": "inspect", "draft": doc] as [String: Any])
        } else {
            if let c = info.channel { print("Channel: \(c)") }
            print("Recipients: \(info.recipients.joined(separator: ", "))")
            if let b = info.body { print("Body: \(b)") }
            print("Characters: \(info.characterCount)")
        }
    }
}

struct MsgTemplatesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "templates", abstract: "List message templates")
    @Flag(name: .long, help: "Output as JSON") var json = false

    func run() throws {
        let templates = MessageTemplateEngine.list()
        if json {
            let items = templates.map { ["name": $0.name, "description": $0.description, "pattern": $0.pattern] as [String: String] }
            pj(["ok": true, "tool": "ztp-message", "templates": items] as [String: Any])
        } else {
            for t in templates {
                print("\(t.name)")
                print("  \(t.description)")
                print("  Pattern: \(t.pattern)")
            }
        }
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

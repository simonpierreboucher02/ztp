import ArgumentParser
import Foundation
import ZTPCore
import ZTPProtocols

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect a registered ZTP tool (manifest + commands)"
    )

    @Argument(help: "Tool name (e.g. excel, ztp-excel)")
    var toolName: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        guard let tool = BuiltinTools.find(toolName) else {
            FileHandle.standardError.write(Data("Unknown tool '\(toolName)'\n".utf8))
            throw ExitCode(1)
        }
        let m = tool.manifest
        let doc = ToolCatalog.doc(for: m.name)

        if json {
            if let schema = ToolCatalog.jsonSchema(for: m.name) {
                JSONOutput.print(InspectPayload(
                    name: m.name,
                    version: m.version,
                    protocolVersion: m.protocolVersion,
                    capabilities: m.capabilities,
                    permissions: m.permissions,
                    schema: schema
                ))
            } else {
                JSONOutput.print(m)
            }
            return
        }

        print("Tool: \(m.name)  v\(m.version)  (protocol \(m.protocolVersion))")
        if let doc { print(doc.summary) }
        print("Capabilities: \(m.capabilities.joined(separator: ", "))")
        let perms = m.permissions.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        print("Permissions: \(perms)")
        if let doc {
            print("")
            print("Commands (\(doc.commands.count)):")
            for cmd in doc.commands {
                print("  \(cmd.name) — \(cmd.summary)")
                for p in cmd.params {
                    let req = p.required ? " (required)" : ""
                    print("      \(p.name): \(p.type)\(req) — \(p.description)")
                }
            }
        }
    }

    private struct InspectPayload: Encodable {
        let name: String
        let version: String
        let protocolVersion: String
        let capabilities: [String]
        let permissions: [String: Bool]
        let schema: JSONValue
        enum CodingKeys: String, CodingKey {
            case name, version
            case protocolVersion = "protocol"
            case capabilities, permissions, schema
        }
    }
}

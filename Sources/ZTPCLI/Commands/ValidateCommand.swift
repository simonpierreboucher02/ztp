import ArgumentParser
import Foundation
import ZTPCore
import ZTPProtocols

struct ValidateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a spec file against a tool's schema"
    )

    @Argument(help: "Tool name (e.g. excel, ztp-excel)")
    var toolName: String

    @Argument(help: "Path to the spec file to validate")
    var specFile: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() async throws {
        guard let tool = BuiltinTools.find(toolName) else {
            FileHandle.standardError.write(Data("Unknown tool '\(toolName)'\n".utf8))
            throw ExitCode(1)
        }

        // Pick the tool's validation command: most tools expose "validate-spec";
        // mail/message expose "validate".
        let commands = ToolCatalog.doc(for: tool.manifest.name)?.commands.map(\.name) ?? []
        let validateCmd = commands.contains("validate-spec") ? "validate-spec"
            : (commands.contains("validate") ? "validate" : "validate-spec")

        let params: [String: JSONValue] = [
            "command": .string(validateCmd),
            "input": .string(specFile),
        ]

        let runtime = await BuiltinTools.makeRuntime()
        let result = try await runtime.execute(
            toolName: tool.manifest.name,
            input: ToolInput(parameters: params),
            context: BuiltinTools.makeContext()
        )

        if json {
            JSONOutput.print(result)
        } else {
            let valid: Bool
            if case .bool(let v)? = result.data?["valid"] { valid = v } else { valid = result.ok }
            print(valid ? "✓ valid" : "✗ invalid")
            if case .int(let n)? = result.data?["error_count"], n > 0 {
                print("  \(n) error(s)")
            }
            if let err = result.error {
                print("  error [\(err.code)]: \(err.message)")
            }
        }

        let valid: Bool
        if case .bool(let v)? = result.data?["valid"] { valid = v } else { valid = result.ok }
        if !valid { throw ExitCode(1) }
    }
}

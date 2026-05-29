import ArgumentParser
import Foundation
import ZTPCore
import ZTPProtocols

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a ZTP tool by name with a JSON input"
    )

    @Argument(help: "Tool name (e.g. excel, ztp-excel)")
    var toolName: String

    @Argument(help: "Path to a JSON input file (a flat object of parameters). Omit to read stdin.")
    var inputFile: String?

    @Option(name: .long, help: "Override/set the 'command' parameter")
    var command: String?

    @Option(name: .long, parsing: .singleValue, help: "Set a parameter: key=value (repeatable)")
    var set: [String] = []

    @Flag(name: .long, help: "Output the full ToolResult as JSON")
    var json = false

    func run() async throws {
        guard let tool = BuiltinTools.find(toolName) else {
            let names = BuiltinTools.manifests().map { BuiltinTools.shortName($0.name) }.joined(separator: ", ")
            FileHandle.standardError.write(Data("Unknown tool '\(toolName)'. Available: \(names)\n".utf8))
            throw ExitCode(1)
        }

        // Assemble the parameters object.
        var params: [String: JSONValue] = [:]
        var rawData: Data?

        if let inputFile {
            let data = try Data(contentsOf: URL(fileURLWithPath: inputFile))
            rawData = data
            params = try decodeParams(data)
        } else if let stdin = readStdinIfPiped() {
            rawData = stdin
            if !stdin.isEmpty { params = try decodeParams(stdin) }
        }

        if let command { params["command"] = .string(command) }
        for entry in set {
            let parts = entry.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                FileHandle.standardError.write(Data("Invalid --set '\(entry)' (use key=value)\n".utf8))
                throw ExitCode(1)
            }
            params[String(parts[0])] = parseScalar(String(parts[1]))
        }

        guard params["command"] != nil else {
            FileHandle.standardError.write(Data(
                "No 'command' specified. Provide it in the input JSON or via --command. See: ztp schema \(toolName)\n".utf8))
            throw ExitCode(1)
        }

        let runtime = await BuiltinTools.makeRuntime()
        let result = try await runtime.execute(
            toolName: tool.manifest.name,
            input: ToolInput(parameters: params, rawJSON: rawData),
            context: BuiltinTools.makeContext()
        )

        if json {
            JSONOutput.print(result)
        } else {
            printHuman(result)
        }
        if !result.ok { throw ExitCode(1) }
    }

    // MARK: - Helpers

    private func decodeParams(_ data: Data) throws -> [String: JSONValue] {
        do {
            return try JSONDecoder().decode([String: JSONValue].self, from: data)
        } catch {
            FileHandle.standardError.write(Data("Input is not a flat JSON object of parameters: \(error)\n".utf8))
            throw ExitCode(1)
        }
    }

    private func parseScalar(_ s: String) -> JSONValue {
        if s == "true" { return .bool(true) }
        if s == "false" { return .bool(false) }
        if let i = Int(s) { return .int(i) }
        if let d = Double(s) { return .double(d) }
        return .string(s)
    }

    /// Read stdin only when it is piped (not an interactive TTY).
    private func readStdinIfPiped() -> Data? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return nil }
        return FileHandle.standardInput.readDataToEndOfFile()
    }

    private func printHuman(_ result: ToolResult) {
        let mark = result.ok ? "✓" : "✗"
        let dur = result.durationMs.map { " (\($0)ms)" } ?? ""
        print("\(mark) \(result.tool)\(dur)")
        if let err = result.error {
            print("  error [\(err.code)]: \(err.message)")
        }
        if let data = result.data {
            for key in data.keys.sorted() {
                print("  \(key): \(scalarString(data[key]!))")
            }
        }
    }

    private func scalarString(_ v: JSONValue) -> String {
        switch v {
        case .string(let s): return s
        case .int(let i): return "\(i)"
        case .double(let d): return "\(d)"
        case .bool(let b): return "\(b)"
        case .null: return "null"
        case .array(let a): return "[\(a.count) items]"
        case .object(let o): return "{\(o.count) fields}"
        }
    }
}

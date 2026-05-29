import ArgumentParser
import Foundation
import ZTPCore
import ZTPProtocols

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Display a tool's input schema (commands + parameters)"
    )

    @Argument(help: "Tool name (e.g. excel, ztp-excel)")
    var toolName: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let canonical = BuiltinTools.canonicalName(toolName)
        guard BuiltinTools.find(toolName) != nil, let schema = ToolCatalog.jsonSchema(for: canonical) else {
            FileHandle.standardError.write(Data("No schema for tool '\(toolName)'\n".utf8))
            throw ExitCode(1)
        }

        // The schema is itself JSON; always print it as JSON (it is the schema).
        let wrapper = SchemaWrapper(schema: schema)
        JSONOutput.print(wrapper.schema)
    }

    private struct SchemaWrapper: Encodable {
        let schema: JSONValue
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(schema)
        }
    }
}

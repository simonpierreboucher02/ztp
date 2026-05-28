import ArgumentParser

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Display tool schemas"
    )

    @Argument(help: "Tool name")
    var toolName: String

    @Flag(name: .long, help: "Show input schema")
    var input = false

    @Flag(name: .long, help: "Show output schema")
    var output = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        print("Schema display not yet implemented.")
        print("Tool: \(toolName)")
    }
}

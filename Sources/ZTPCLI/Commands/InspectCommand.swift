import ArgumentParser

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect a registered tool"
    )

    @Argument(help: "Tool name to inspect")
    var toolName: String

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        print("Tool inspection not yet implemented.")
        print("Tool: \(toolName)")
    }
}

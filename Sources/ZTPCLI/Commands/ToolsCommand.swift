import ArgumentParser
import Foundation

struct ToolsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List registered tools"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        if json {
            let output: [String: Any] = [
                "tools": [] as [Any],
                "count": 0,
            ]
            let data = try JSONSerialization.data(
                withJSONObject: output,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("No tools registered.")
            print("Tool discovery paths:")
            print("  ~/.ztp/tools/")
            print("  /usr/local/lib/ztp/")
            print("  /opt/homebrew/lib/ztp/")
        }
    }
}

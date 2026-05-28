import ArgumentParser
import Foundation

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Display ZTP version information"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        if json {
            let output: [String: String] = [
                "version": "0.1.0",
                "protocol": "ztp/1",
                "platform": "macOS",
                "swift": "6.0",
            ]
            let data = try JSONSerialization.data(
                withJSONObject: output,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("ztp 0.1.0")
            print("Protocol: ztp/1")
            print("Platform: macOS (Apple Silicon)")
            print("Swift: 6.0")
        }
    }
}

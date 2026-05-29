import ArgumentParser
import Foundation
import ZTPCore
import ZTPProtocols

struct ToolsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List registered ZTP tools"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    private struct Listing: Encodable {
        let tools: [ToolManifest]
        let count: Int
    }

    func run() throws {
        let manifests = BuiltinTools.manifests()

        if json {
            JSONOutput.print(Listing(tools: manifests, count: manifests.count))
            return
        }

        print("ZTP Tools (\(manifests.count)):")
        print(String(repeating: "─", count: 64))
        let nameWidth = manifests.map { BuiltinTools.shortName($0.name).count }.max() ?? 8
        for m in manifests {
            let short = BuiltinTools.shortName(m.name).padding(toLength: nameWidth + 2, withPad: " ", startingAt: 0)
            let summary = ToolCatalog.doc(for: m.name)?.summary ?? m.capabilities.prefix(3).joined(separator: ", ")
            print("  \(short) v\(m.version)  \(summary)")
        }
        print("")
        print("Run a tool:      ztp run <tool> <input.json>")
        print("Inspect a tool:  ztp inspect <tool>")
        print("Tool schema:     ztp schema <tool>")
    }
}

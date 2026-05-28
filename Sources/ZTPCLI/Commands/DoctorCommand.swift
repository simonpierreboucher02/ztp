import ArgumentParser
import Foundation

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check ZTP installation health"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let checks: [(String, Bool)] = [
            ("Swift runtime", true),
            ("macOS platform", true),
            ("Config directory (~/.ztp)", FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.ztp")),
            ("Tools directory (~/.ztp/tools)", FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.ztp/tools")),
            ("Workspace directory (~/.ztp/workspaces)", FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.ztp/workspaces")),
        ]

        if self.json {
            let results = checks.map { ["check": $0.0, "ok": $0.1] as [String: Any] }
            let output: [String: Any] = ["checks": results]
            let data = try JSONSerialization.data(
                withJSONObject: output,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("ZTP Doctor")
            print("----------")
            for (name, ok) in checks {
                let status = ok ? "OK" : "MISSING"
                print("  \(status)  \(name)")
            }
        }
    }
}

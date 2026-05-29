import Foundation
import ZTPCore
import ZTPProtocols
import ZTPExcel
import ZTPDocx
import ZTPSlides
import ZTPChart
import ZTPMail
import ZTPMessage
import ZTPBrowser
import ZTPMacOS

/// Central registry of the built-in ZTP tools. This is what makes the
/// `ztp run / tools / schema / inspect / validate` commands work: every tool
/// already conforms to `ZTPTool`, but nothing registered them until now.
public enum BuiltinTools {

    /// All built-in tool instances, ordered for stable listing.
    public static func all() -> [any ZTPTool] {
        [
            ZTPExcelTool(),
            ZTPDocxTool(),
            ZTPSlidesTool(),
            ZTPChartTool(),
            ZTPMailTool(),
            ZTPMessageTool(),
            ZTPBrowserTool(),
            ZTPMacOSTool(),
        ]
    }

    /// All manifests, sorted by name.
    public static func manifests() -> [ToolManifest] {
        all().map(\.manifest).sorted { $0.name < $1.name }
    }

    /// A runtime with every built-in tool registered.
    public static func makeRuntime() async -> ZTPRuntime {
        let runtime = ZTPRuntime()
        for tool in all() {
            await runtime.register(tool: tool)
        }
        return runtime
    }

    /// Resolve a tool by a flexible name: accepts the canonical manifest name
    /// (`ztp-excel`), the short name (`excel`), or `ztp_excel`.
    public static func find(_ name: String) -> (any ZTPTool)? {
        let target = canonicalName(name)
        return all().first { $0.manifest.name == target }
    }

    /// Normalize a user-supplied tool name to the canonical `ztp-<x>` form.
    public static func canonicalName(_ name: String) -> String {
        var n = name.lowercased().replacingOccurrences(of: "_", with: "-")
        if !n.hasPrefix("ztp-") { n = "ztp-\(n)" }
        return n
    }

    /// The short name (`excel`) for a canonical manifest name (`ztp-excel`).
    public static func shortName(_ manifestName: String) -> String {
        manifestName.hasPrefix("ztp-") ? String(manifestName.dropFirst(4)) : manifestName
    }

    /// A `ToolContext` rooted at the current working directory.
    public static func makeContext() -> ToolContext {
        ToolContext(
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            environment: ProcessInfo.processInfo.environment,
            traceID: "cli-\(UUID().uuidString.prefix(8))"
        )
    }
}

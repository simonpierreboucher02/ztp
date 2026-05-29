import Foundation

/// Safe AppleScript helpers shared across the macOS tools.
///
/// Two hardening rules:
/// 1. `escape` covers backslash, quote AND newline/cr/tab — the previous
///    per-site escapers only handled the double quote, so a crafted app name
///    or path could break out of the string and inject commands.
/// 2. `run` invokes `/usr/bin/osascript` via `Process` argument arrays
///    (`-e <script>`), never through a shell string. This removes the
///    shell-quoting layer (`osascript -e '...'`) that was itself injectable.
public enum AppleScriptSafe {

    /// Escape a value for inclusion inside an AppleScript double-quoted literal.
    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Run an AppleScript and return trimmed stdout (empty on failure).
    /// No shell is involved.
    @discardableResult
    public static func run(_ script: String) -> String {
        let process = Process()
        let outPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Result of a checked AppleScript run.
    public struct ScriptOutcome: Sendable {
        public let ok: Bool
        public let output: String
        public let error: String
        public init(ok: Bool, output: String, error: String) {
            self.ok = ok; self.output = output; self.error = error
        }
    }

    /// Run an AppleScript capturing stdout, stderr and the exit status — so
    /// callers can surface real failures instead of silently getting `""`.
    public static func runChecked(_ script: String) -> ScriptOutcome {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ScriptOutcome(ok: false, output: "", error: error.localizedDescription)
        }
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ScriptOutcome(ok: process.terminationStatus == 0, output: out, error: err)
    }
}

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
}

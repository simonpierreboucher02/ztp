import Foundation

// MARK: - ShortcutsBridge

public struct ShortcutsBridge: Sendable {

    // MARK: - Models

    public struct ShortcutInfo: Codable, Sendable {
        public let name: String
    }

    public struct ShortcutResult: Sendable {
        public let success: Bool
        public let output: String?
        public let message: String
    }

    // MARK: - Public API

    /// Lists all available Shortcuts using the `shortcuts list` command.
    public static func list() throws -> [ShortcutInfo] {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw ShortcutsError.listFailed(errMsg)
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ShortcutInfo(name: $0) }
    }

    /// Runs a named Shortcut. Requires `confirmed == true`.
    public static func run(name: String, confirmed: Bool) throws -> ShortcutResult {
        guard confirmed else {
            throw ShortcutsError.notConfirmed("run shortcut \(name)")
        }

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errMsg = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
            return ShortcutResult(
                success: true,
                output: output?.isEmpty == true ? nil : output,
                message: "Shortcut '\(name)' executed successfully"
            )
        } else {
            return ShortcutResult(
                success: false,
                output: nil,
                message: "Shortcut '\(name)' failed: \(errMsg ?? "Unknown error")"
            )
        }
    }
}

// MARK: - Errors

public enum ShortcutsError: Error, Sendable {
    case listFailed(String)
    case notConfirmed(String)
}

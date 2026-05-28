import Foundation

// MARK: - AppleScriptEngine

public struct AppleScriptEngine: Sendable {

    // MARK: - Models

    public struct ScriptResult: Sendable {
        public let success: Bool
        public let output: String?
        public let error: String?
    }

    // MARK: - Public API

    /// Executes an inline AppleScript string. Requires `confirmed == true`.
    public static func run(script: String, confirmed: Bool) throws -> ScriptResult {
        guard confirmed else {
            throw AppleScriptError.notConfirmed("run AppleScript")
        }
        guard validate(script: script) else {
            throw AppleScriptError.invalidScript("Script is empty or invalid")
        }

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
            return ScriptResult(
                success: true,
                output: output?.isEmpty == true ? nil : output,
                error: nil
            )
        } else {
            return ScriptResult(
                success: false,
                output: nil,
                error: errorOutput?.isEmpty == true ? "Script failed with exit code \(process.terminationStatus)" : errorOutput
            )
        }
    }

    /// Executes an AppleScript file. Requires `confirmed == true`.
    public static func runFile(path: String, confirmed: Bool) throws -> ScriptResult {
        guard confirmed else {
            throw AppleScriptError.notConfirmed("run AppleScript file")
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw AppleScriptError.fileNotFound(expandedPath)
        }

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [expandedPath]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
            return ScriptResult(
                success: true,
                output: output?.isEmpty == true ? nil : output,
                error: nil
            )
        } else {
            return ScriptResult(
                success: false,
                output: nil,
                error: errorOutput?.isEmpty == true ? "Script failed with exit code \(process.terminationStatus)" : errorOutput
            )
        }
    }

    /// Basic validation: checks that the script is non-empty.
    public static func validate(script: String) -> Bool {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
}

// MARK: - Errors

public enum AppleScriptError: Error, Sendable {
    case notConfirmed(String)
    case invalidScript(String)
    case fileNotFound(String)
}

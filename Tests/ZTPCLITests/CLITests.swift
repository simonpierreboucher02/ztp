import Testing
import Foundation

@Suite("CLI Integration Tests")
struct CLITests {

    @Test("Version command output contains version string")
    func versionOutput() throws {
        let binary = binaryPath()
        guard FileManager.default.fileExists(atPath: binary) else {
            Issue.record("Binary not found at \(binary) — run swift build first")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #expect(process.terminationStatus == 0)
        #expect(output.contains("0.1.0"))
    }

    @Test("Help flag produces subcommand list")
    func helpOutput() throws {
        let binary = binaryPath()
        guard FileManager.default.fileExists(atPath: binary) else {
            Issue.record("Binary not found at \(binary) — run swift build first")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--help"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #expect(process.terminationStatus == 0)
        #expect(output.contains("SUBCOMMANDS"))
    }

    private func binaryPath() -> String {
        let file = #filePath
        let packageRoot = URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        return packageRoot + "/.build/debug/ztp"
    }
}

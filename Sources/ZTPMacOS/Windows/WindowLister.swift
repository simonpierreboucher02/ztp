import Foundation

// MARK: - WindowLister

public struct WindowLister: Sendable {

    // MARK: - Models

    public struct WindowInfo: Codable, Sendable {
        public let app: String
        public let title: String
        public let index: Int
    }

    // MARK: - Public API

    /// Lists all visible windows across all applications using AppleScript + System Events.
    public static func list() throws -> [WindowInfo] {
        let script = """
            set output to ""
            tell application "System Events"
                repeat with proc in (every process whose visible is true)
                    set procName to name of proc
                    set winList to every window of proc
                    set winIndex to 1
                    repeat with w in winList
                        try
                            set winTitle to name of w
                            set output to output & procName & "|||" & winTitle & "|||" & winIndex & linefeed
                        end try
                        set winIndex to winIndex + 1
                    end repeat
                end repeat
            end tell
            return output
            """

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw WindowListerError.scriptFailed(errMsg)
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var results: [WindowInfo] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|||")
            guard parts.count >= 3 else { continue }

            let app = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let index = Int(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1

            results.append(WindowInfo(app: app, title: title, index: index))
        }

        return results
    }
}

// MARK: - Errors

public enum WindowListerError: Error, Sendable {
    case scriptFailed(String)
}

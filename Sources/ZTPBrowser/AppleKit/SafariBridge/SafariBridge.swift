import Foundation

public struct SafariBridge: Sendable {

    public struct SafariResult: Sendable {
        public let success: Bool
        public let message: String
        public let data: String?

        public init(success: Bool, message: String, data: String? = nil) {
            self.success = success
            self.message = message
            self.data = data
        }
    }

    public enum SafariError: Error, Sendable {
        case scriptFailed(String)
        case safariNotRunning
        case noWindowOpen
        case processError(String)
    }

    // MARK: - Public API

    public static func openURL(_ url: String) throws -> SafariResult {
        let script = """
        tell application "Safari"
            open location "\(escapeForAppleScript(url))"
            activate
        end tell
        """
        let output = try runAppleScript(script)
        return SafariResult(success: true, message: "Opened URL in Safari.", data: output)
    }

    public static func currentURL() throws -> SafariResult {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then
                error "No Safari window is open."
            end if
            set currentURL to URL of current tab of front window
            return currentURL
        end tell
        """
        let output = try runAppleScript(script)
        return SafariResult(success: true, message: "Retrieved current URL.", data: output)
    }

    public static func currentTitle() throws -> SafariResult {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then
                error "No Safari window is open."
            end if
            set pageTitle to name of current tab of front window
            return pageTitle
        end tell
        """
        let output = try runAppleScript(script)
        return SafariResult(success: true, message: "Retrieved current page title.", data: output)
    }

    public static func pageSource() throws -> SafariResult {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then
                error "No Safari window is open."
            end if
            set pageHTML to do JavaScript "document.documentElement.outerHTML" in current tab of front window
            return pageHTML
        end tell
        """
        let output = try runAppleScript(script)
        return SafariResult(success: true, message: "Retrieved page source.", data: output)
    }

    // MARK: - Private Helpers

    private static func runAppleScript(_ script: String) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw SafariError.processError("Failed to launch osascript: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let status = process.terminationStatus
        if status != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"

            if errorMsg.contains("No Safari window") || errorMsg.contains("Can't get window") {
                throw SafariError.noWindowOpen
            }
            if errorMsg.contains("not running") || errorMsg.contains("Connection is invalid") {
                throw SafariError.safariNotRunning
            }

            throw SafariError.scriptFailed(errorMsg)
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty == true) ? nil : output
    }

    private static func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

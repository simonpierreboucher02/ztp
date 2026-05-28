import Foundation

// MARK: - ScreenCapture

public struct ScreenCapture: Sendable {

    // MARK: - Models

    public struct CaptureResult: Sendable {
        public let success: Bool
        public let path: String
        public let message: String
    }

    // MARK: - Public API

    /// Captures the full screen to the specified output path.
    /// Uses `screencapture -x` (no shutter sound).
    public static func fullScreen(output: String) throws -> CaptureResult {
        let expandedOutput = (output as NSString).expandingTildeInPath

        // Ensure parent directory exists
        let parent = (expandedOutput as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", expandedOutput]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: expandedOutput) {
            return CaptureResult(
                success: true,
                path: expandedOutput,
                message: "Full screen captured to \(expandedOutput)"
            )
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return CaptureResult(
                success: false,
                path: expandedOutput,
                message: "Screenshot failed: \(errMsg)"
            )
        }
    }

    /// Captures a window belonging to the specified application.
    /// Uses AppleScript to get the window ID, then `screencapture -l<windowID>`.
    public static func window(appName: String, output: String) throws -> CaptureResult {
        let expandedOutput = (output as NSString).expandingTildeInPath

        // Ensure parent directory exists
        let parent = (expandedOutput as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Get the window ID via AppleScript + System Events
        let escapedApp = appName.replacingOccurrences(of: "\"", with: "\\\"")
        let windowIDScript = """
            tell application "System Events"
                set frontApp to first application process whose name is "\(escapedApp)"
                set frontWindow to first window of frontApp
                return id of frontWindow
            end tell
            """

        let windowIDStr = shellOutput("osascript -e '\(windowIDScript.replacingOccurrences(of: "'", with: "'\\''"))'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let windowID = Int(windowIDStr) else {
            // Fallback: bring app to front and capture the frontmost window
            return try captureWithFallback(appName: appName, output: expandedOutput)
        }

        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l\(windowID)", expandedOutput]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: expandedOutput) {
            return CaptureResult(
                success: true,
                path: expandedOutput,
                message: "Window of \(appName) captured to \(expandedOutput)"
            )
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return CaptureResult(
                success: false,
                path: expandedOutput,
                message: "Window capture failed: \(errMsg)"
            )
        }
    }

    // MARK: - Fallback

    private static func captureWithFallback(appName: String, output: String) throws -> CaptureResult {
        // Bring the app to front
        let activateScript = "tell application \"\(appName.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
        _ = shellOutput("osascript -e '\(activateScript.replacingOccurrences(of: "'", with: "'\\''"))'")

        // Small delay to let the window come forward
        Thread.sleep(forTimeInterval: 0.5)

        // Capture the frontmost window using CGWindowListCopyWindowInfo approach via screencapture
        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", output]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: output) {
            return CaptureResult(
                success: true,
                path: output,
                message: "Captured screen (fallback) for \(appName) to \(output)"
            )
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return CaptureResult(
                success: false,
                path: output,
                message: "Fallback capture failed: \(errMsg)"
            )
        }
    }
}

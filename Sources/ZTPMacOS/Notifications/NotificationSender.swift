import Foundation

// MARK: - NotificationSender

public struct NotificationSender: Sendable {

    // MARK: - Models

    public struct NotifyResult: Sendable {
        public let success: Bool
        public let message: String
    }

    // MARK: - Public API

    /// Sends a macOS notification using AppleScript `display notification`.
    public static func send(
        title: String,
        subtitle: String?,
        body: String?,
        sound: Bool
    ) throws -> NotifyResult {
        var script = "display notification"

        // Body (the notification text)
        let bodyText = body ?? ""
        script += " \"\(escapeAppleScript(bodyText))\""

        // Title
        script += " with title \"\(escapeAppleScript(title))\""

        // Subtitle
        if let subtitle = subtitle, !subtitle.isEmpty {
            script += " subtitle \"\(escapeAppleScript(subtitle))\""
        }

        // Sound
        if sound {
            script += " sound name \"default\""
        }

        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return NotifyResult(success: true, message: "Notification sent: \(title)")
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return NotifyResult(success: false, message: "Failed to send notification: \(errMsg)")
        }
    }

    // MARK: - Helpers

    private static func escapeAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

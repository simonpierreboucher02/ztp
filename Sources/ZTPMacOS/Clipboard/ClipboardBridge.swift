import Foundation

// MARK: - ClipboardBridge

public struct ClipboardBridge: Sendable {

    // MARK: - Models

    public struct ClipboardResult: Sendable {
        public let success: Bool
        public let content: String?
        public let message: String
    }

    // MARK: - Public API

    /// Gets the current clipboard text content using `pbpaste`.
    public static func get() -> ClipboardResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbpaste")
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let content = String(data: data, encoding: .utf8) ?? ""
            return ClipboardResult(
                success: true,
                content: content,
                message: "Clipboard content retrieved (\(content.count) characters)"
            )
        } catch {
            return ClipboardResult(
                success: false,
                content: nil,
                message: "Failed to read clipboard: \(error.localizedDescription)"
            )
        }
    }

    /// Sets the clipboard text content using `pbcopy`.
    public static func set(_ text: String) -> ClipboardResult {
        let process = Process()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        process.standardInput = inputPipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            if let data = text.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return ClipboardResult(
                    success: true,
                    content: text,
                    message: "Clipboard set (\(text.count) characters)"
                )
            } else {
                return ClipboardResult(
                    success: false,
                    content: nil,
                    message: "pbcopy exited with status \(process.terminationStatus)"
                )
            }
        } catch {
            return ClipboardResult(
                success: false,
                content: nil,
                message: "Failed to set clipboard: \(error.localizedDescription)"
            )
        }
    }
}

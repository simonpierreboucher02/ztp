import Foundation

// MARK: - PermissionChecker

public struct PermissionChecker: Sendable {

    // MARK: - Models

    public struct PermissionStatus: Codable, Sendable {
        public let accessibility: Bool
        public let automation: Bool
        public let screenRecording: Bool
        public let fullDiskAccess: Bool
    }

    // MARK: - Public API

    /// Checks the current permission status for key macOS capabilities.
    /// Results are best-effort — some checks may not be 100% reliable.
    public static func check() -> PermissionStatus {
        return PermissionStatus(
            accessibility: checkAccessibility(),
            automation: checkAutomation(),
            screenRecording: checkScreenRecording(),
            fullDiskAccess: checkFullDiskAccess()
        )
    }

    // MARK: - Individual Checks

    /// Checks accessibility permission by trying to interact with System Events.
    private static func checkAccessibility() -> Bool {
        let script = "tell application \"System Events\" to get name of first process"
        let output = shellOutput("osascript -e '\(script)' 2>&1")
        // If accessibility is denied, osascript will include an error message
        return !output.lowercased().contains("not allowed") &&
               !output.lowercased().contains("error") &&
               !output.isEmpty
    }

    /// Checks automation permission by trying to run a basic System Events command.
    private static func checkAutomation() -> Bool {
        let script = "tell application \"System Events\" to return 1"
        let output = shellOutput("osascript -e '\(script)' 2>&1")
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "1"
    }

    /// Checks screen recording permission by attempting a screenshot and checking the result.
    private static func checkScreenRecording() -> Bool {
        let testPath = NSTemporaryDirectory() + "ztp_perm_test_\(ProcessInfo.processInfo.processIdentifier).png"

        // Clean up any previous test file
        try? FileManager.default.removeItem(atPath: testPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", testPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        defer { try? FileManager.default.removeItem(atPath: testPath) }

        // Check if the file was created and is non-empty
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: testPath),
              let size = attrs[.size] as? Int64 else {
            return false
        }

        // A very small file (< 1KB) may indicate a blocked screenshot
        return size > 1024
    }

    /// Checks full disk access by trying to read a TCC-protected path.
    private static func checkFullDiskAccess() -> Bool {
        let protectedPaths = [
            NSHomeDirectory() + "/Library/Mail",
            NSHomeDirectory() + "/Library/Safari/Bookmarks.plist",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]

        for path in protectedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        return false
    }
}

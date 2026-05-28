import Foundation

// MARK: - AppLauncher

public struct AppLauncher: Sendable {

    // MARK: - Models

    public struct AppInfo: Codable, Sendable {
        public let name: String
        public let bundleID: String?
        public let path: String?
        public let isRunning: Bool
    }

    public struct LaunchResult: Sendable {
        public let success: Bool
        public let message: String
    }

    // MARK: - Public API

    /// Opens an application by name using the `open -a` command.
    public static func open(appName: String) throws -> LaunchResult {
        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return LaunchResult(success: true, message: "Opened \(appName)")
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return LaunchResult(success: false, message: "Failed to open \(appName): \(errMsg)")
        }
    }

    /// Quits an application by name using AppleScript. Requires `confirmed == true`.
    public static func quit(appName: String, confirmed: Bool) throws -> LaunchResult {
        guard confirmed else {
            throw AppLauncherError.notConfirmed("quit \(appName)")
        }

        let escaped = appName.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"\(escaped)\" to quit"

        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return LaunchResult(success: true, message: "Quit \(appName)")
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return LaunchResult(success: false, message: "Failed to quit \(appName): \(errMsg)")
        }
    }

    /// Lists installed applications from /Applications and ~/Applications.
    public static func listInstalled() throws -> [AppInfo] {
        let fm = FileManager.default
        var apps: [AppInfo] = []

        let searchPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        for searchPath in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: searchPath) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (searchPath as NSString).appendingPathComponent(item)
                let name = (item as NSString).deletingPathExtension

                // Try to get bundle ID
                var bundleID: String? = nil
                let plistPath = (fullPath as NSString).appendingPathComponent("Contents/Info.plist")
                if let plistData = fm.contents(atPath: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(
                       from: plistData, format: nil
                   ) as? [String: Any] {
                    bundleID = plist["CFBundleIdentifier"] as? String
                }

                apps.append(AppInfo(
                    name: name,
                    bundleID: bundleID,
                    path: fullPath,
                    isRunning: false
                ))
            }
        }

        // Mark running apps
        let runningNames = Set(runningAppNames())
        apps = apps.map { app in
            if runningNames.contains(app.name) {
                return AppInfo(
                    name: app.name,
                    bundleID: app.bundleID,
                    path: app.path,
                    isRunning: true
                )
            }
            return app
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Lists currently running GUI applications.
    public static func listRunning() -> [AppInfo] {
        let script = """
            tell application "System Events"
                set appList to ""
                repeat with p in (every process whose background only is false)
                    set appList to appList & name of p & "\\n"
                end repeat
                return appList
            end tell
            """
        let output = shellOutput("osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")
        let names = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return names.map { name in
            AppInfo(name: name, bundleID: nil, path: nil, isRunning: true)
        }
    }

    // MARK: - Helpers

    private static func runningAppNames() -> [String] {
        let script = """
            tell application "System Events"
                return name of every process whose background only is false
            end tell
            """
        let output = shellOutput("osascript -e '\(script.replacingOccurrences(of: "'", with: "'\\''"))'")
        return output.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Errors

public enum AppLauncherError: Error, Sendable {
    case notConfirmed(String)
}

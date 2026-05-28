import Foundation
import ZTPCore
import ZTPProtocols

// MARK: - ZTPMacOSTool

public struct ZTPMacOSTool: ZTPTool {

    public let manifest = ToolManifest(
        name: "ztp-macos",
        version: "0.1.0",
        protocolVersion: "ztp/1",
        capabilities: [
            "system.info",
            "system.disks",
            "system.memory",
            "system.battery",
            "finder.reveal",
            "finder.list",
            "files.read",
            "files.write",
            "files.copy",
            "files.move",
            "files.delete",
            "files.exists",
            "files.info",
            "clipboard.get",
            "clipboard.set",
            "notify",
            "screenshot.full",
            "screenshot.window",
            "apps.open",
            "apps.list",
            "apps.running",
            "apps.quit",
            "windows.list",
            "processes.list",
            "processes.inspect",
            "applescript.run",
            "applescript.run-file",
            "shortcuts.list",
            "shortcuts.run",
            "permissions.check",
        ],
        permissions: [
            "filesystem": true,
            "process": true,
            "applescript": true,
            "notifications": true,
            "screenshots": true,
        ]
    )

    public init() {}

    public func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult {
        guard let command = input.string(for: "command") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_COMMAND", message: "No command specified.")
            )
        }

        let start = ContinuousClock.now

        do {
            switch command {
            // MARK: System
            case "system-info":
                return executeSystemInfo(start: start)
            case "system-disks":
                return executeSystemDisks(start: start)
            case "system-memory":
                return executeSystemMemory(start: start)
            case "system-battery":
                return executeSystemBattery(start: start)

            // MARK: Finder
            case "finder-reveal":
                return try executeFinderReveal(input: input, start: start)
            case "finder-list":
                return try executeFinderList(input: input, start: start)

            // MARK: Files
            case "files-read":
                return try executeFilesRead(input: input, start: start)
            case "files-write":
                return try executeFilesWrite(input: input, start: start)
            case "files-copy":
                return try executeFilesCopy(input: input, start: start)
            case "files-move":
                return try executeFilesMove(input: input, start: start)
            case "files-delete":
                return try executeFilesDelete(input: input, start: start)
            case "files-exists":
                return executeFilesExists(input: input, start: start)
            case "files-info":
                return try executeFilesInfo(input: input, start: start)

            // MARK: Clipboard
            case "clipboard-get":
                return executeClipboardGet(start: start)
            case "clipboard-set":
                return executeClipboardSet(input: input, start: start)

            // MARK: Notifications
            case "notify":
                return try executeNotify(input: input, start: start)

            // MARK: Screenshots
            case "screenshot-full":
                return try executeScreenshotFull(input: input, start: start)
            case "screenshot-window":
                return try executeScreenshotWindow(input: input, start: start)

            // MARK: Apps
            case "apps-open":
                return try executeAppsOpen(input: input, start: start)
            case "apps-list":
                return try executeAppsList(start: start)
            case "apps-running":
                return executeAppsRunning(start: start)
            case "apps-quit":
                return try executeAppsQuit(input: input, start: start)

            // MARK: Windows
            case "windows-list":
                return try executeWindowsList(start: start)

            // MARK: Processes
            case "processes-list":
                return executeProcessesList(start: start)
            case "processes-inspect":
                return executeProcessesInspect(input: input, start: start)

            // MARK: AppleScript
            case "applescript-run":
                return try executeAppleScriptRun(input: input, start: start)
            case "applescript-run-file":
                return try executeAppleScriptRunFile(input: input, start: start)

            // MARK: Shortcuts
            case "shortcuts-list":
                return try executeShortcutsList(start: start)
            case "shortcuts-run":
                return try executeShortcutsRun(input: input, start: start)

            // MARK: Permissions
            case "permissions-check":
                return executePermissionsCheck(start: start)

            default:
                return ToolResult.failure(
                    tool: manifest.name,
                    error: ToolErrorInfo(code: "UNKNOWN_COMMAND", message: "Unknown command: \(command)")
                )
            }
        } catch {
            let elapsed = elapsedMs(from: start)
            return ToolResult.failure(
                tool: manifest.name,
                durationMs: elapsed,
                error: ToolErrorInfo(code: "EXECUTION_FAILED", message: error.localizedDescription)
            )
        }
    }

    // MARK: - System Commands

    private func executeSystemInfo(start: ContinuousClock.Instant) -> ToolResult {
        let info = SystemInfo.info()
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("system-info"),
            "hostname": .string(info.hostname),
            "macos_version": .string(info.macosVersion),
            "build_version": .string(info.buildVersion),
            "chip": .string(info.chip),
            "cores": .int(info.cores),
            "memory_gb": .int(info.memoryGB),
        ]
        if let serial = info.serialNumber {
            data["serial_number"] = .string(serial)
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    private func executeSystemDisks(start: ContinuousClock.Instant) -> ToolResult {
        let disks = SystemInfo.disks()
        let elapsed = elapsedMs(from: start)
        let diskValues: [JSONValue] = disks.map { disk in
            .object([
                "name": .string(disk.name),
                "mount_point": .string(disk.mountPoint),
                "total_gb": .double(disk.totalGB),
                "free_gb": .double(disk.freeGB),
                "used_percent": .double(disk.usedPercent),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("system-disks"),
            "disks": .array(diskValues),
            "count": .int(disks.count),
        ])
    }

    private func executeSystemMemory(start: ContinuousClock.Instant) -> ToolResult {
        let mem = SystemInfo.memory()
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("system-memory"),
            "total_gb": .int(mem.totalGB),
            "active_processes": .int(mem.activeProcesses),
        ])
    }

    private func executeSystemBattery(start: ContinuousClock.Instant) -> ToolResult {
        let batt = SystemInfo.battery()
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("system-battery"),
            "has_battery": .bool(batt.hasBattery),
        ]
        if let pct = batt.percentage { data["percentage"] = .int(pct) }
        if let charging = batt.isCharging { data["is_charging"] = .bool(charging) }
        if let source = batt.powerSource { data["power_source"] = .string(source) }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - Finder Commands

    private func executeFinderReveal(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let result = try FinderBridge.reveal(path: path)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("finder-reveal"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    private func executeFinderList(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let items = try FinderBridge.list(path: path)
        let elapsed = elapsedMs(from: start)
        let fileValues: [JSONValue] = items.map { item in
            .object([
                "name": .string(item.name),
                "path": .string(item.path),
                "is_directory": .bool(item.isDirectory),
                "size": .int(Int(item.size)),
                "modified": .string(item.modified),
                "type": .string(item.type),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("finder-list"),
            "path": .string(path),
            "files": .array(fileValues),
            "count": .int(items.count),
        ])
    }

    // MARK: - File Commands

    private func executeFilesRead(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let content = try FileOperations.read(path: path)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-read"),
            "path": .string(path),
            "content": .string(content),
            "length": .int(content.count),
        ])
    }

    private func executeFilesWrite(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        guard let content = input.string(for: "content") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_CONTENT", message: "No content specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try FileOperations.write(path: path, content: content, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-write"),
            "success": .bool(result.success),
            "message": .string(result.message),
            "path": .string(result.path ?? path),
        ])
    }

    private func executeFilesCopy(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let from = input.string(for: "from") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_FROM", message: "No source path specified.")
            )
        }
        guard let to = input.string(for: "to") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_TO", message: "No destination path specified.")
            )
        }
        let result = try FileOperations.copy(from: from, to: to)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-copy"),
            "success": .bool(result.success),
            "message": .string(result.message),
            "path": .string(result.path ?? to),
        ])
    }

    private func executeFilesMove(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let from = input.string(for: "from") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_FROM", message: "No source path specified.")
            )
        }
        guard let to = input.string(for: "to") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_TO", message: "No destination path specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try FileOperations.move(from: from, to: to, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-move"),
            "success": .bool(result.success),
            "message": .string(result.message),
            "path": .string(result.path ?? to),
        ])
    }

    private func executeFilesDelete(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try FileOperations.delete(path: path, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-delete"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    private func executeFilesExists(input: ToolInput, start: ContinuousClock.Instant) -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let exists = FileOperations.exists(path: path)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-exists"),
            "path": .string(path),
            "exists": .bool(exists),
        ])
    }

    private func executeFilesInfo(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No path specified.")
            )
        }
        let info = try FileOperations.info(path: path)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("files-info"),
            "name": .string(info.name),
            "path": .string(info.path),
            "is_directory": .bool(info.isDirectory),
            "size": .int(Int(info.size)),
            "modified": .string(info.modified),
            "type": .string(info.type),
        ])
    }

    // MARK: - Clipboard Commands

    private func executeClipboardGet(start: ContinuousClock.Instant) -> ToolResult {
        let result = ClipboardBridge.get()
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("clipboard-get"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ]
        if let content = result.content {
            data["content"] = .string(content)
            data["length"] = .int(content.count)
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    private func executeClipboardSet(input: ToolInput, start: ContinuousClock.Instant) -> ToolResult {
        guard let text = input.string(for: "text") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_TEXT", message: "No text specified.")
            )
        }
        let result = ClipboardBridge.set(text)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("clipboard-set"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    // MARK: - Notification Commands

    private func executeNotify(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let title = input.string(for: "title") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_TITLE", message: "No title specified.")
            )
        }
        let subtitle = input.string(for: "subtitle")
        let body = input.string(for: "body")
        let sound = input.bool(for: "sound") ?? true
        let result = try NotificationSender.send(title: title, subtitle: subtitle, body: body, sound: sound)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("notify"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    // MARK: - Screenshot Commands

    private func executeScreenshotFull(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let output = input.string(for: "output") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path specified.")
            )
        }
        let result = try ScreenCapture.fullScreen(output: output)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("screenshot-full"),
            "success": .bool(result.success),
            "path": .string(result.path),
            "message": .string(result.message),
        ])
    }

    private func executeScreenshotWindow(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let appName = input.string(for: "app") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_APP", message: "No app name specified.")
            )
        }
        guard let output = input.string(for: "output") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_OUTPUT", message: "No output path specified.")
            )
        }
        let result = try ScreenCapture.window(appName: appName, output: output)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("screenshot-window"),
            "success": .bool(result.success),
            "path": .string(result.path),
            "message": .string(result.message),
        ])
    }

    // MARK: - App Commands

    private func executeAppsOpen(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let appName = input.string(for: "app") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_APP", message: "No app name specified.")
            )
        }
        let result = try AppLauncher.open(appName: appName)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apps-open"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    private func executeAppsList(start: ContinuousClock.Instant) throws -> ToolResult {
        let apps = try AppLauncher.listInstalled()
        let elapsed = elapsedMs(from: start)
        let appValues: [JSONValue] = apps.map { app in
            var obj: [String: JSONValue] = [
                "name": .string(app.name),
                "is_running": .bool(app.isRunning),
            ]
            if let bid = app.bundleID { obj["bundle_id"] = .string(bid) }
            if let path = app.path { obj["path"] = .string(path) }
            return .object(obj)
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apps-list"),
            "apps": .array(appValues),
            "count": .int(apps.count),
        ])
    }

    private func executeAppsRunning(start: ContinuousClock.Instant) -> ToolResult {
        let apps = AppLauncher.listRunning()
        let elapsed = elapsedMs(from: start)
        let appValues: [JSONValue] = apps.map { app in
            .object([
                "name": .string(app.name),
                "is_running": .bool(true),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apps-running"),
            "apps": .array(appValues),
            "count": .int(apps.count),
        ])
    }

    private func executeAppsQuit(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let appName = input.string(for: "app") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_APP", message: "No app name specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try AppLauncher.quit(appName: appName, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("apps-quit"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ])
    }

    // MARK: - Window Commands

    private func executeWindowsList(start: ContinuousClock.Instant) throws -> ToolResult {
        let windows = try WindowLister.list()
        let elapsed = elapsedMs(from: start)
        let windowValues: [JSONValue] = windows.map { win in
            .object([
                "app": .string(win.app),
                "title": .string(win.title),
                "index": .int(win.index),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("windows-list"),
            "windows": .array(windowValues),
            "count": .int(windows.count),
        ])
    }

    // MARK: - Process Commands

    private func executeProcessesList(start: ContinuousClock.Instant) -> ToolResult {
        let processes = ProcessInspector.list()
        let elapsed = elapsedMs(from: start)
        let procValues: [JSONValue] = processes.prefix(200).map { proc in
            .object([
                "name": .string(proc.name),
                "pid": .int(proc.pid),
                "cpu": .double(proc.cpu),
                "memory_mb": .double(proc.memory),
                "user": .string(proc.user),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("processes-list"),
            "processes": .array(procValues),
            "count": .int(processes.count),
        ])
    }

    private func executeProcessesInspect(input: ToolInput, start: ContinuousClock.Instant) -> ToolResult {
        guard let name = input.string(for: "name") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_NAME", message: "No process name specified.")
            )
        }
        let processes = ProcessInspector.inspect(name: name)
        let elapsed = elapsedMs(from: start)
        let procValues: [JSONValue] = processes.map { proc in
            .object([
                "name": .string(proc.name),
                "pid": .int(proc.pid),
                "cpu": .double(proc.cpu),
                "memory_mb": .double(proc.memory),
                "user": .string(proc.user),
            ])
        }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("processes-inspect"),
            "name": .string(name),
            "processes": .array(procValues),
            "count": .int(processes.count),
        ])
    }

    // MARK: - AppleScript Commands

    private func executeAppleScriptRun(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let script = input.string(for: "script") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_SCRIPT", message: "No script specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try AppleScriptEngine.run(script: script, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("applescript-run"),
            "success": .bool(result.success),
        ]
        if let output = result.output { data["output"] = .string(output) }
        if let error = result.error { data["error"] = .string(error) }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    private func executeAppleScriptRunFile(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let path = input.string(for: "path") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_PATH", message: "No script path specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try AppleScriptEngine.runFile(path: path, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("applescript-run-file"),
            "success": .bool(result.success),
        ]
        if let output = result.output { data["output"] = .string(output) }
        if let error = result.error { data["error"] = .string(error) }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - Shortcut Commands

    private func executeShortcutsList(start: ContinuousClock.Instant) throws -> ToolResult {
        let shortcuts = try ShortcutsBridge.list()
        let elapsed = elapsedMs(from: start)
        let values: [JSONValue] = shortcuts.map { .object(["name": .string($0.name)]) }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("shortcuts-list"),
            "shortcuts": .array(values),
            "count": .int(shortcuts.count),
        ])
    }

    private func executeShortcutsRun(input: ToolInput, start: ContinuousClock.Instant) throws -> ToolResult {
        guard let name = input.string(for: "name") else {
            return ToolResult.failure(
                tool: manifest.name,
                error: ToolErrorInfo(code: "MISSING_NAME", message: "No shortcut name specified.")
            )
        }
        let confirmed = input.bool(for: "confirmed") ?? false
        let result = try ShortcutsBridge.run(name: name, confirmed: confirmed)
        let elapsed = elapsedMs(from: start)
        var data: [String: JSONValue] = [
            "command": .string("shortcuts-run"),
            "success": .bool(result.success),
            "message": .string(result.message),
        ]
        if let output = result.output { data["output"] = .string(output) }
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: data)
    }

    // MARK: - Permission Commands

    private func executePermissionsCheck(start: ContinuousClock.Instant) -> ToolResult {
        let status = PermissionChecker.check()
        let elapsed = elapsedMs(from: start)
        return ToolResult.success(tool: manifest.name, durationMs: elapsed, data: [
            "command": .string("permissions-check"),
            "accessibility": .bool(status.accessibility),
            "automation": .bool(status.automation),
            "screen_recording": .bool(status.screenRecording),
            "full_disk_access": .bool(status.fullDiskAccess),
        ])
    }

    // MARK: - Helpers

    private func elapsedMs(from start: ContinuousClock.Instant) -> Int64 {
        let elapsed = start.duration(to: .now)
        return elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
    }
}

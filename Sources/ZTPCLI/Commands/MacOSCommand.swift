import ArgumentParser
import Foundation
import ZTPMacOS

struct MacOSCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "macos",
        abstract: "Native macOS automation and system integration",
        subcommands: [
            MacSystemCommand.self, MacFinderCommand.self, MacFilesCommand.self,
            MacClipboardCommand.self, MacNotifyCommand.self, MacScreenshotCommand.self,
            MacAppsCommand.self, MacWindowsCommand.self, MacProcessesCommand.self,
            MacAppleScriptCommand.self, MacShortcutsCommand.self, MacPermissionsCommand.self,
        ]
    )
}

// MARK: - System

struct MacSystemCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "system", abstract: "System information",
        subcommands: [SysInfoCmd.self, SysDisksCmd.self, SysMemCmd.self, SysBatCmd.self])
}

struct SysInfoCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "System overview")
    @Flag(name: .long, help: "JSON") var json = false
    func run() {
        let i = SystemInfo.info()
        if json { pj(["ok":true,"tool":"ztp-macos","command":"system.info","system":["hostname":i.hostname,"macos_version":i.macosVersion,"chip":i.chip,"cores":i.cores,"memory_gb":i.memoryGB] as [String:Any]] as [String:Any]) }
        else { print("Hostname: \(i.hostname)\nmacOS: \(i.macosVersion)\nChip: \(i.chip)\nCores: \(i.cores)\nRAM: \(i.memoryGB) GB") }
    }
}
struct SysDisksCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "disks", abstract: "Disk info")
    @Flag(name: .long, help: "JSON") var json = false
    func run() {
        let d = SystemInfo.disks()
        if json { pj(["ok":true,"tool":"ztp-macos","disks":d.map{["name":$0.name,"mount":$0.mountPoint,"total_gb":$0.totalGB,"free_gb":$0.freeGB] as [String:Any]}] as [String:Any]) }
        else { for disk in d { print("\(disk.name): \(String(format:"%.1f",disk.freeGB))/\(String(format:"%.1f",disk.totalGB)) GB free") } }
    }
}
struct SysMemCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "memory", abstract: "Memory info")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let m = SystemInfo.memory(); if json { pj(["ok":true,"tool":"ztp-macos","memory":["total_gb":m.totalGB,"processes":m.activeProcesses] as [String:Any]] as [String:Any]) } else { print("RAM: \(m.totalGB) GB, Processes: \(m.activeProcesses)") } }
}
struct SysBatCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "battery", abstract: "Battery info")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let b = SystemInfo.battery(); if json { pj(["ok":true,"tool":"ztp-macos","battery":["has_battery":b.hasBattery,"percentage":b.percentage ?? -1,"is_charging":b.isCharging ?? false] as [String:Any]] as [String:Any]) } else { if b.hasBattery { print("Battery: \(b.percentage ?? 0)%\(b.isCharging == true ? " (charging)" : "")") } else { print("No battery (desktop)") } } }
}

// MARK: - Finder

struct MacFinderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "finder", abstract: "Finder integration",
        subcommands: [FinderRevealCmd.self, FinderListCmd.self, FinderOpenCmd.self])
}
struct FinderRevealCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reveal", abstract: "Reveal in Finder")
    @Argument var path: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try FinderBridge.reveal(path: path); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}
struct FinderListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List directory")
    @Argument var path: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let items = try FinderBridge.list(path: path); if json { pj(["ok":true,"tool":"ztp-macos","items":items.map{["name":$0.name,"is_dir":$0.isDirectory,"size":$0.size] as [String:Any]},"count":items.count] as [String:Any]) } else { for i in items { print("\(i.isDirectory ? "📁" : "📄") \(i.name) (\(i.size) bytes)") } } }
}
struct FinderOpenCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open", abstract: "Open folder")
    @Argument var path: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try FinderBridge.openFolder(path: path); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}

// MARK: - Files

struct MacFilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "files", abstract: "File operations",
        subcommands: [FilesReadCmd.self, FilesWriteCmd.self, FilesCopyCmd.self, FilesMoveCmd.self])
}
struct FilesReadCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "read", abstract: "Read file")
    @Argument var path: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let c = try FileOperations.read(path: path); if json { pj(["ok":true,"tool":"ztp-macos","content":c,"chars":c.count] as [String:Any]) } else { print(c) } }
}
struct FilesWriteCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "write", abstract: "Write file")
    @Argument var path: String
    @Option(name: .long) var input: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let content = try String(contentsOfFile: input, encoding: .utf8); let r = try FileOperations.write(path: path, content: content, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}
struct FilesCopyCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "copy", abstract: "Copy file")
    @Argument var source: String
    @Argument var dest: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try FileOperations.copy(from: source, to: dest); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}
struct FilesMoveCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "move", abstract: "Move file")
    @Argument var source: String
    @Argument var dest: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try FileOperations.move(from: source, to: dest, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}

// MARK: - Clipboard

struct MacClipboardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "Clipboard",
        subcommands: [ClipGetCmd.self, ClipSetCmd.self])
}
struct ClipGetCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Get clipboard")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let r = ClipboardBridge.get(); if json { pj(["ok":r.success,"tool":"ztp-macos","content":r.content ?? ""] as [String:Any]) } else { print(r.content ?? "(empty)") } }
}
struct ClipSetCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set clipboard")
    @Argument var text: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let r = ClipboardBridge.set(text); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}

// MARK: - Notify

struct MacNotifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "notify", abstract: "Send notification")
    @Argument(help: "Notification title") var title: String
    @Option(name: .long) var subtitle: String?
    @Option(name: .long) var body: String?
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try NotificationSender.send(title: title, subtitle: subtitle, body: body, sound: true); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}

// MARK: - Screenshot

struct MacScreenshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Screen capture",
        subcommands: [ScreenFullCmd.self, ScreenWindowCmd.self])
}
struct ScreenFullCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "full", abstract: "Full screen")
    @Option(name: .long) var output: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try ScreenCapture.fullScreen(output: output); if json { pj(["ok":r.success,"tool":"ztp-macos","output":r.path] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}
struct ScreenWindowCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "window", abstract: "Window capture")
    @Argument var appName: String
    @Option(name: .long) var output: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try ScreenCapture.window(appName: appName, output: output); if json { pj(["ok":r.success,"tool":"ztp-macos","output":r.path] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}

// MARK: - Apps

struct MacAppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apps", abstract: "App management",
        subcommands: [AppsOpenCmd.self, AppsListCmd.self, AppsRunningCmd.self, AppsQuitCmd.self])
}
struct AppsOpenCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open", abstract: "Open app")
    @Argument var appName: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try AppLauncher.open(appName: appName); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) } }
}
struct AppsListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "Installed apps")
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let apps = try AppLauncher.listInstalled(); if json { pj(["ok":true,"tool":"ztp-macos","apps":apps.map{["name":$0.name,"path":$0.path ?? ""] as [String:String]},"count":apps.count] as [String:Any]) } else { for a in apps { print(a.name) } } }
}
struct AppsRunningCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "running", abstract: "Running apps")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let apps = AppLauncher.listRunning(); if json { pj(["ok":true,"tool":"ztp-macos","apps":apps.map{$0.name},"count":apps.count] as [String:Any]) } else { for a in apps { print(a.name) } } }
}
struct AppsQuitCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "quit", abstract: "Quit app")
    @Argument var appName: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try AppLauncher.quit(appName: appName, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}

// MARK: - Windows & Processes

struct MacWindowsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "windows", abstract: "Window listing",
        subcommands: [WinListCmd.self])
}
struct WinListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List windows")
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let w = try WindowLister.list(); if json { pj(["ok":true,"tool":"ztp-macos","windows":w.map{["app":$0.app,"title":$0.title] as [String:String]},"count":w.count] as [String:Any]) } else { for win in w { print("\(win.app): \(win.title)") } } }
}

struct MacProcessesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "processes", abstract: "Process info",
        subcommands: [ProcListCmd.self, ProcInspectCmd.self])
}
struct ProcListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List processes")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let p = ProcessInspector.list(); if json { pj(["ok":true,"tool":"ztp-macos","processes":p.prefix(50).map{["name":$0.name,"pid":$0.pid,"cpu":$0.cpu,"memory_mb":$0.memory] as [String:Any]},"count":p.count] as [String:Any]) } else { for proc in p.prefix(20) { print("[\(proc.pid)] \(proc.name) — CPU: \(proc.cpu)%, Mem: \(String(format:"%.0f",proc.memory)) MB") } } }
}
struct ProcInspectCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect process")
    @Argument var name: String
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let p = ProcessInspector.inspect(name: name); if json { pj(["ok":true,"tool":"ztp-macos","processes":p.map{["name":$0.name,"pid":$0.pid,"cpu":$0.cpu,"memory_mb":$0.memory] as [String:Any]}] as [String:Any]) } else { for proc in p { print("[\(proc.pid)] \(proc.name) — CPU: \(proc.cpu)%, Mem: \(String(format:"%.0f",proc.memory)) MB") } } }
}

// MARK: - AppleScript

struct MacAppleScriptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "applescript", abstract: "AppleScript",
        subcommands: [ASRunCmd.self, ASEvalCmd.self])
}
struct ASRunCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run script file")
    @Argument var scriptFile: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try AppleScriptEngine.runFile(path: scriptFile, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","output":r.output ?? "","error":r.error ?? ""] as [String:Any]) } else { if let o = r.output { print(o) }; if let e = r.error { print("Error: \(e)") } }; if !r.success { throw ExitCode.failure } }
}
struct ASEvalCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "eval", abstract: "Evaluate inline script")
    @Argument var script: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try AppleScriptEngine.run(script: script, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","output":r.output ?? "","error":r.error ?? ""] as [String:Any]) } else { if let o = r.output { print(o) }; if let e = r.error { print("Error: \(e)") } }; if !r.success { throw ExitCode.failure } }
}

// MARK: - Shortcuts

struct MacShortcutsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "shortcuts", abstract: "Shortcuts",
        subcommands: [ShortcutsListCmd.self, ShortcutsRunCmd.self])
}
struct ShortcutsListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List shortcuts")
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let s = try ShortcutsBridge.list(); if json { pj(["ok":true,"tool":"ztp-macos","shortcuts":s.map{$0.name},"count":s.count] as [String:Any]) } else { for sc in s { print(sc.name) } } }
}
struct ShortcutsRunCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run shortcut")
    @Argument var name: String
    @Flag(name: .long) var confirm = false
    @Flag(name: .long, help: "JSON") var json = false
    func run() throws { let r = try ShortcutsBridge.run(name: name, confirmed: confirm); if json { pj(["ok":r.success,"tool":"ztp-macos","message":r.message,"output":r.output ?? ""] as [String:Any]) } else { print(r.message) }; if !r.success { throw ExitCode.failure } }
}

// MARK: - Permissions

struct MacPermissionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "permissions", abstract: "Permission diagnostics",
        subcommands: [PermCheckCmd.self])
}
struct PermCheckCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Check permissions")
    @Flag(name: .long, help: "JSON") var json = false
    func run() { let p = PermissionChecker.check(); if json { pj(["ok":true,"tool":"ztp-macos","permissions":["accessibility":p.accessibility,"automation":p.automation,"screen_recording":p.screenRecording,"full_disk_access":p.fullDiskAccess] as [String:Any]] as [String:Any]) } else { print("Accessibility: \(p.accessibility ? "✓" : "✗")\nAutomation: \(p.automation ? "✓" : "✗")\nScreen Recording: \(p.screenRecording ? "✓" : "✗")\nFull Disk Access: \(p.fullDiskAccess ? "✓" : "✗")") } }
}

private func pj(_ d: [String: Any]) { if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted,.sortedKeys]), let s = String(data: data, encoding: .utf8) { print(s) } }

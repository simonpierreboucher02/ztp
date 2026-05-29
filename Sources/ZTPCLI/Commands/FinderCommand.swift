import ArgumentParser
import Foundation
import ZTPFinder

struct FinderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "finder",
        abstract: "Advanced Finder control via AppleScript",
        subcommands: [
            FinderToolSelectionCmd.self, FinderToolRevealCmd.self, FinderToolOpenCmd.self,
            FinderToolNewWindowCmd.self, FinderToolSetViewCmd.self, FinderToolInfoCmd.self,
            FinderToolTrashCmd.self, FinderToolEmptyTrashCmd.self, FinderToolEjectCmd.self,
        ]
    )
}

private func finderPJ(_ d: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: data, encoding: .utf8) { print(s) }
}
private func emitFinder(_ r: FinderResult, _ command: String, _ json: Bool) {
    if json { finderPJ(["ok": r.success, "tool": "ztp-finder", "command": command, "message": r.message] as [String: Any]) }
    else { print(r.message) }
}

struct FinderToolSelectionCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "selection", abstract: "Get selected items")
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let items = try FinderControl.selection()
        if json { finderPJ(["ok": true, "tool": "ztp-finder", "command": "selection", "items": items, "count": items.count] as [String: Any]) }
        else { for i in items { print(i) } }
    }
}

struct FinderToolRevealCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reveal", abstract: "Reveal a path")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.reveal(path: path), "reveal", json) }
}

struct FinderToolOpenCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open", abstract: "Open a folder/file")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.open(path: path), "open", json) }
}

struct FinderToolNewWindowCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "new-window", abstract: "Open a new Finder window")
    @Option(name: .long, help: "Optional path") var path: String?
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.newWindow(path: path), "new-window", json) }
}

struct FinderToolSetViewCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-view", abstract: "Set window view (icon|list|column|gallery)")
    @Option(name: .long, help: "View mode") var view: String
    @Option(name: .long, help: "Optional path to open first") var path: String?
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.setView(view, path: path), "set-view", json) }
}

struct FinderToolInfoCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Finder kind/size for a path")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try FinderControl.info(path: path)
        if json { finderPJ(["ok": r.success, "tool": "ztp-finder", "command": "info", "message": r.message, "kind": r.detail ?? ""] as [String: Any]) }
        else { print(r.message) }
    }
}

struct FinderToolTrashCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "trash", abstract: "Move a path to Trash")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.trash(path: path, confirmed: confirm), "trash", json) }
}

struct FinderToolEmptyTrashCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "empty-trash", abstract: "Empty the Trash")
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.emptyTrash(confirmed: confirm), "empty-trash", json) }
}

struct FinderToolEjectCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "eject", abstract: "Eject a volume by name")
    @Option(name: .long, help: "Volume name") var name: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emitFinder(try FinderControl.eject(name: name, confirmed: confirm), "eject", json) }
}

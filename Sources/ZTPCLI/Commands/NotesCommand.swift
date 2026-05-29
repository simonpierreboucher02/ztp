import ArgumentParser
import Foundation
import ZTPNotes

struct NotesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notes",
        abstract: "Read and write Apple Notes",
        subcommands: [
            NotesListCmd.self, NotesReadCmd.self, NotesCreateCmd.self,
            NotesAppendCmd.self, NotesDeleteCmd.self, NotesFoldersCmd.self,
        ]
    )
}

struct NotesListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List notes")
    @Option(name: .long, help: "Restrict to a folder") var folder: String?
    @Option(name: .long, help: "Max notes to return (default 50)") var limit: Int = 50
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let items = try NotesBridge.list(folder: folder, limit: limit)
        if json {
            notesPJ(["ok": true, "tool": "ztp-notes", "command": "list", "count": items.count,
                     "notes": items.map { ["name": $0.name, "folder": $0.folder, "modified": $0.modified] }] as [String: Any])
        } else { for i in items { print("\(i.folder) › \(i.name)") } }
    }
}

struct NotesReadCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "read", abstract: "Read a note by title")
    @Option(name: .long, help: "Note title") var name: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let n = try NotesBridge.read(name: name)
        if json {
            notesPJ(["ok": true, "tool": "ztp-notes", "command": "read", "name": n.name, "folder": n.folder,
                     "text": n.plainText, "html": n.bodyHTML, "char_count": n.plainText.count] as [String: Any])
        } else { print(n.plainText) }
    }
}

struct NotesCreateCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a note")
    @Option(name: .long, help: "Note title") var title: String
    @Option(name: .long, help: "Body text or HTML") var body: String = ""
    @Option(name: .long, help: "Target folder") var folder: String?
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try NotesBridge.create(title: title, body: body, folder: folder)
        if json { notesPJ(["ok": r.success, "tool": "ztp-notes", "command": "create", "message": r.message, "title": title] as [String: Any]) }
        else { print(r.message) }
    }
}

struct NotesAppendCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "append", abstract: "Append to a note")
    @Option(name: .long, help: "Note title") var name: String
    @Option(name: .long, help: "Text or HTML to append") var body: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try NotesBridge.append(name: name, body: body)
        if json { notesPJ(["ok": r.success, "tool": "ztp-notes", "command": "append", "message": r.message] as [String: Any]) }
        else { print(r.message) }
    }
}

struct NotesDeleteCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a note (to Recently Deleted)")
    @Option(name: .long, help: "Note title") var name: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required to delete") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let r = try NotesBridge.delete(name: name, confirmed: confirm)
        if json { notesPJ(["ok": r.success, "tool": "ztp-notes", "command": "delete", "message": r.message] as [String: Any]) }
        else { print(r.message) }
    }
}

struct NotesFoldersCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "folders", abstract: "List Notes folders")
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let f = try NotesBridge.folders()
        if json { notesPJ(["ok": true, "tool": "ztp-notes", "command": "folders", "folders": f, "count": f.count] as [String: Any]) }
        else { for name in f { print(name) } }
    }
}

private func notesPJ(_ d: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: data, encoding: .utf8) { print(s) }
}

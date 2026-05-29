import ArgumentParser
import Foundation
import ZTPFiles

struct FilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "files",
        abstract: "File navigation, search, copy/move/rename and compression",
        subcommands: [
            FilesToolListCmd.self, FilesToolTreeCmd.self, FilesToolSearchCmd.self, FilesToolInfoCmd.self,
            FilesToolCopyCmd.self, FilesToolMoveCmd.self, FilesToolRenameCmd.self, FilesToolMkdirCmd.self,
            FilesToolDeleteCmd.self, FilesToolCompressCmd.self, FilesToolExtractCmd.self,
        ]
    )
}

private func filesPJ(_ d: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: data, encoding: .utf8) { print(s) }
}
private func entryDict(_ e: FileEntry, depth: Bool = false) -> [String: Any] {
    var d: [String: Any] = ["name": e.name, "path": e.path, "is_directory": e.isDirectory,
                            "is_symlink": e.isSymlink, "size": e.size, "modified": e.modified, "type": e.ext]
    if depth { d["depth"] = e.depth }
    return d
}

struct FilesToolListCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List a directory")
    @Option(name: .long, help: "Directory path") var path: String
    @Option(name: .long, help: "Sort: name|size|date") var sort: String = "name"
    @Flag(name: .long, help: "Include hidden entries") var all = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let entries = try FilesEngine.list(path: path, includeHidden: all, sort: FilesEngine.SortKey(rawValue: sort) ?? .name)
        if json { filesPJ(["ok": true, "tool": "ztp-files", "command": "list", "path": path, "count": entries.count, "entries": entries.map { entryDict($0) }] as [String: Any]) }
        else { for e in entries { print("\(e.isDirectory ? "📁" : "📄") \(e.name)") } }
    }
}

struct FilesToolTreeCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tree", abstract: "Recursive tree")
    @Option(name: .long, help: "Root path") var path: String
    @Option(name: .long, help: "Max depth (default 3)") var depth: Int = 3
    @Option(name: .long, help: "Max entries (default 2000)") var max: Int = 2000
    @Flag(name: .long, help: "Include hidden entries") var all = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let entries = try FilesEngine.tree(path: path, maxDepth: depth, maxEntries: max, includeHidden: all)
        if json { filesPJ(["ok": true, "tool": "ztp-files", "command": "tree", "path": path, "count": entries.count, "entries": entries.map { entryDict($0, depth: true) }] as [String: Any]) }
        else { for e in entries { print(String(repeating: "  ", count: e.depth) + (e.isDirectory ? "📁 " : "📄 ") + e.name) } }
    }
}

struct FilesToolSearchCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "Search by name or content")
    @Option(name: .long, help: "Root path") var path: String
    @Option(name: .long, help: "Query (substring or regex)") var query: String
    @Option(name: .long, help: "Restrict to extension, e.g. swift") var ext: String?
    @Option(name: .long, help: "Max results (default 200)") var max: Int = 200
    @Flag(name: .long, help: "Treat query as regex") var regex = false
    @Flag(name: .long, help: "Search file contents (grep)") var content = false
    @Flag(name: .long, help: "Include hidden entries") var all = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let matches = try FilesEngine.search(path: path, query: query, regex: regex, searchContent: content, ext: ext, maxResults: max, includeHidden: all)
        if json {
            filesPJ(["ok": true, "tool": "ztp-files", "command": "search", "path": path, "query": query, "count": matches.count,
                     "results": matches.map { m -> [String: Any] in
                         var d: [String: Any] = ["path": m.path, "name": m.name, "is_directory": m.isDirectory, "size": m.size]
                         if !m.lineMatches.isEmpty { d["matches"] = m.lineMatches.map { ["line": $0.line, "text": $0.text] } }
                         return d
                     }] as [String: Any])
        } else { for m in matches { print(m.path) } }
    }
}

struct FilesToolInfoCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Stat a path")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws {
        let e = try FilesEngine.info(path: path)
        if json { filesPJ(["ok": true, "tool": "ztp-files", "command": "info"].merging(entryDict(e)) { _, b in b } as [String: Any]) }
        else { print("\(e.name) — \(e.isDirectory ? "dir" : e.ext), \(e.size) bytes, \(e.modified)") }
    }
}

struct FilesToolCopyCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "copy", abstract: "Copy a file/dir")
    @Option(name: .long, help: "Source") var from: String
    @Option(name: .long, help: "Destination") var to: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.copy(from: from, to: to), "copy", json) }
}

struct FilesToolMoveCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "move", abstract: "Move a file/dir")
    @Option(name: .long, help: "Source") var from: String
    @Option(name: .long, help: "Destination") var to: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.move(from: from, to: to, confirmed: confirm), "move", json) }
}

struct FilesToolRenameCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rename", abstract: "Rename a file/dir")
    @Option(name: .long, help: "Path") var path: String
    @Option(name: .long, help: "New name") var name: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.rename(path: path, newName: name, confirmed: confirm), "rename", json) }
}

struct FilesToolMkdirCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "mkdir", abstract: "Create a directory")
    @Option(name: .long, help: "Directory path") var path: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.mkdir(path: path), "mkdir", json) }
}

struct FilesToolDeleteCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete (to Trash unless --permanent)")
    @Option(name: .long, help: "Path") var path: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Permanently delete instead of Trash") var permanent = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.delete(path: path, confirmed: confirm, permanent: permanent), "delete", json) }
}

struct FilesToolCompressCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "compress", abstract: "Zip a file/dir")
    @Option(name: .long, help: "Path to compress") var path: String
    @Option(name: .long, help: "Output .zip path") var output: String
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.compress(path: path, output: output), "compress", json) }
}

struct FilesToolExtractCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "extract", abstract: "Unzip an archive")
    @Option(name: .long, help: "Input .zip path") var input: String
    @Option(name: .long, help: "Destination directory") var to: String
    @Flag(name: [.customLong("confirm"), .customLong("confirmed")], help: "Required") var confirm = false
    @Flag(name: .long, help: "Output as JSON") var json = false
    func run() throws { emit(try FilesEngine.extract(input: input, to: to, confirmed: confirm), "extract", json) }
}

private func emit(_ r: OpResult, _ command: String, _ json: Bool) {
    if json {
        var d: [String: Any] = ["ok": r.success, "tool": "ztp-files", "command": command, "message": r.message]
        if let p = r.path { d["path"] = p }
        filesPJ(d)
    } else { print(r.message) }
}

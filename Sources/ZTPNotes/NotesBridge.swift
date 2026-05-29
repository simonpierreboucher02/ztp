import Foundation
import ZTPMacOS

// MARK: - Models

public struct NoteSummary: Sendable {
    public let name: String
    public let folder: String
    public let modified: String
}

public struct NoteContent: Sendable {
    public let name: String
    public let folder: String
    public let bodyHTML: String
    public let plainText: String
}

public struct NotesResult: Sendable {
    public let success: Bool
    public let message: String
}

public enum NotesError: Error, Sendable, CustomStringConvertible {
    case notFound(String)
    case scriptFailed(String)
    case notConfirmed(String)
    public var description: String {
        switch self {
        case .notFound(let n): return "Note not found: \(n)"
        case .scriptFailed(let m): return "Notes automation failed: \(m)"
        case .notConfirmed(let a): return "Operation requires --confirm: \(a)"
        }
    }
}

// MARK: - NotesBridge

/// Read/write Apple Notes via AppleScript. Uses `AppleScriptSafe` so every
/// interpolated value is escaped and `osascript` runs without a shell.
public enum NotesBridge {

    private static let sep = "\u{001F}"   // unit separator for safe field splitting
    private static let rec = "\u{001E}"   // record separator

    /// List notes, optionally within a folder, newest first (as Notes orders).
    public static func list(folder: String?, limit: Int) throws -> [NoteSummary] {
        let target = folder.map { "folder \"\(AppleScriptSafe.escape($0))\"" } ?? "default account"
        let script = """
        set out to ""
        tell application "Notes"
            repeat with n in (notes of \(target))
                set out to out & (name of n) & "\(sep)" & (name of container of n) & "\(sep)" & (modification date of n as string) & "\(rec)"
            end repeat
        end tell
        return out
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error.isEmpty ? "could not list notes" : outcome.error) }
        var items: [NoteSummary] = []
        for record in outcome.output.components(separatedBy: rec) where !record.isEmpty {
            let f = record.components(separatedBy: sep)
            guard f.count >= 3 else { continue }
            items.append(NoteSummary(name: f[0], folder: f[1], modified: f[2]))
        }
        if limit > 0 && items.count > limit { items = Array(items.prefix(limit)) }
        return items
    }

    /// List folder names.
    public static func folders() throws -> [String] {
        let script = """
        set out to ""
        tell application "Notes"
            repeat with f in folders
                set out to out & (name of f) & "\(rec)"
            end repeat
        end tell
        return out
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error) }
        return outcome.output.components(separatedBy: rec).filter { !$0.isEmpty }
    }

    /// Read a note's body by (case-insensitive) title.
    public static func read(name: String) throws -> NoteContent {
        let esc = AppleScriptSafe.escape(name)
        let script = """
        tell application "Notes"
            set matches to (every note whose name is "\(esc)")
            if (count of matches) is 0 then return "__NOT_FOUND__"
            set n to item 1 of matches
            return (name of n) & "\(sep)" & (name of container of n) & "\(sep)" & (body of n)
        end tell
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error) }
        if outcome.output == "__NOT_FOUND__" { throw NotesError.notFound(name) }
        let parts = outcome.output.components(separatedBy: sep)
        let title = parts.count > 0 ? parts[0] : name
        let folder = parts.count > 1 ? parts[1] : ""
        let html = parts.count > 2 ? parts[2...].joined(separator: sep) : ""
        return NoteContent(name: title, folder: folder, bodyHTML: html, plainText: stripHTML(html))
    }

    /// Create a note. `body` may be plain text or HTML.
    public static func create(title: String, body: String, folder: String?) throws -> NotesResult {
        let html = makeBodyHTML(title: title, body: body)
        let bodyEsc = AppleScriptSafe.escape(html)
        let creationTarget: String
        if let folder {
            creationTarget = "at folder \"\(AppleScriptSafe.escape(folder))\""
        } else {
            creationTarget = ""
        }
        let script = """
        tell application "Notes"
            make new note \(creationTarget) with properties {body:"\(bodyEsc)"}
        end tell
        return "OK"
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error) }
        return NotesResult(success: true, message: "Created note \"\(title)\"\(folder.map { " in \($0)" } ?? "")")
    }

    /// Append HTML/text to an existing note.
    public static func append(name: String, body: String) throws -> NotesResult {
        let esc = AppleScriptSafe.escape(name)
        let add = AppleScriptSafe.escape("<div><br></div>" + escapeForBody(body))
        let script = """
        tell application "Notes"
            set matches to (every note whose name is "\(esc)")
            if (count of matches) is 0 then return "__NOT_FOUND__"
            set n to item 1 of matches
            set body of n to (body of n) & "\(add)"
        end tell
        return "OK"
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error) }
        if outcome.output == "__NOT_FOUND__" { throw NotesError.notFound(name) }
        return NotesResult(success: true, message: "Appended to note \"\(name)\"")
    }

    /// Delete a note (moves it to Recently Deleted). Requires confirmation.
    public static func delete(name: String, confirmed: Bool) throws -> NotesResult {
        guard confirmed else { throw NotesError.notConfirmed("delete note \(name)") }
        let esc = AppleScriptSafe.escape(name)
        let script = """
        tell application "Notes"
            set matches to (every note whose name is "\(esc)")
            if (count of matches) is 0 then return "__NOT_FOUND__"
            delete item 1 of matches
        end tell
        return "OK"
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw NotesError.scriptFailed(outcome.error) }
        if outcome.output == "__NOT_FOUND__" { throw NotesError.notFound(name) }
        return NotesResult(success: true, message: "Deleted note \"\(name)\" (moved to Recently Deleted)")
    }

    // MARK: - HTML helpers

    /// Build a Notes-compatible HTML body whose first line is the title.
    static func makeBodyHTML(title: String, body: String) -> String {
        let titleHTML = "<div><h1>\(htmlEscape(title))</h1></div>"
        return titleHTML + escapeForBody(body)
    }

    /// If body already looks like HTML keep it, else escape and convert
    /// newlines to <div> blocks so Notes renders paragraphs.
    static func escapeForBody(_ body: String) -> String {
        if body.contains("<") && body.contains(">") { return body }
        let lines = body.components(separatedBy: "\n")
        return lines.map { "<div>\($0.isEmpty ? "<br>" : htmlEscape($0))</div>" }.joined()
    }

    static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Very small HTML→text reducer for read output (strips tags, decodes a few entities).
    static func stripHTML(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<div>", with: "\n")
            .replacingOccurrences(of: "</div>", with: "")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
        // strip remaining tags
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text.replaceSubrange(range, with: "")
        }
        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

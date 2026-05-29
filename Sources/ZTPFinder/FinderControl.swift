import Foundation
import ZTPMacOS

// MARK: - Models

public struct FinderResult: Sendable {
    public let success: Bool
    public let message: String
    public let detail: String?
    public init(success: Bool, message: String, detail: String? = nil) {
        self.success = success; self.message = message; self.detail = detail
    }
}

public enum FinderControlError: Error, Sendable, CustomStringConvertible {
    case scriptFailed(String)
    case notConfirmed(String)
    case notFound(String)
    case invalidView(String)
    public var description: String {
        switch self {
        case .scriptFailed(let m): return "Finder automation failed: \(m)"
        case .notConfirmed(let a): return "Operation requires --confirm: \(a)"
        case .notFound(let p): return "Path not found: \(p)"
        case .invalidView(let v): return "Invalid view '\(v)' (use icon|list|column|gallery)"
        }
    }
}

// MARK: - FinderControl

/// Advanced Finder control via AppleScript: selection, windows, view modes,
/// reveal/open, trash, empty trash, eject. All values are escaped.
public enum FinderControl {

    private static let rec = "\u{001E}"

    /// POSIX paths of the items currently selected in Finder.
    public static func selection() throws -> [String] {
        let script = """
        set out to ""
        tell application "Finder"
            set sel to selection
            repeat with i in sel
                try
                    set out to out & (POSIX path of (i as alias)) & "\(rec)"
                end try
            end repeat
        end tell
        return out
        """
        let outcome = AppleScriptSafe.runChecked(script)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return outcome.output.components(separatedBy: rec).filter { !$0.isEmpty }
    }

    /// Reveal a path in Finder and bring it to the front.
    public static func reveal(path: String) throws -> FinderResult {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { throw FinderControlError.notFound(expanded) }
        let esc = AppleScriptSafe.escape(expanded)
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            reveal POSIX file "\(esc)"
            activate
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Revealed \(expanded)")
    }

    /// Open a folder (or file) in a Finder window.
    public static func open(path: String) throws -> FinderResult {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { throw FinderControlError.notFound(expanded) }
        let esc = AppleScriptSafe.escape(expanded)
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            open POSIX file "\(esc)"
            activate
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Opened \(expanded)")
    }

    /// Open a brand-new Finder window, optionally at a path.
    public static func newWindow(path: String?) throws -> FinderResult {
        let target: String
        if let path {
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { throw FinderControlError.notFound(expanded) }
            target = "to (POSIX file \"\(AppleScriptSafe.escape(expanded))\" as alias)"
        } else {
            target = "to (path to home folder)"
        }
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            make new Finder window \(target)
            activate
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Opened a new Finder window")
    }

    /// Set the front window's view mode.
    public static func setView(_ view: String, path: String?) throws -> FinderResult {
        let appleView: String
        switch view.lowercased() {
        case "icon": appleView = "icon view"
        case "list": appleView = "list view"
        case "column": appleView = "column view"
        case "gallery", "flow": appleView = "flow view"
        default: throw FinderControlError.invalidView(view)
        }
        var prelude = ""
        if let path {
            let expanded = (path as NSString).expandingTildeInPath
            prelude = "open POSIX file \"\(AppleScriptSafe.escape(expanded))\"\n            delay 0.2\n            "
        }
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            activate
            \(prelude)set current view of front Finder window to \(appleView)
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Set view to \(appleView)")
    }

    /// Finder's "Get Info" kind + size summary for a path.
    public static func info(path: String) throws -> FinderResult {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { throw FinderControlError.notFound(expanded) }
        let esc = AppleScriptSafe.escape(expanded)
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            set theItem to (POSIX file "\(esc)" as alias)
            set theKind to kind of theItem
            set theSize to size of theItem
            return theKind & "\(rec)" & (theSize as string)
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        let parts = outcome.output.components(separatedBy: rec)
        let kind = parts.first ?? "unknown"
        let size = parts.count > 1 ? parts[1] : "0"
        return FinderResult(success: true, message: "\(kind), \(size) bytes", detail: kind)
    }

    /// Move a path to the Trash via Finder. Requires confirmation.
    public static func trash(path: String, confirmed: Bool) throws -> FinderResult {
        guard confirmed else { throw FinderControlError.notConfirmed("trash \(path)") }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { throw FinderControlError.notFound(expanded) }
        let esc = AppleScriptSafe.escape(expanded)
        let outcome = AppleScriptSafe.runChecked("""
        tell application "Finder"
            delete (POSIX file "\(esc)" as alias)
        end tell
        """)
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Moved to Trash: \(expanded)")
    }

    /// Empty the Trash. Requires confirmation.
    public static func emptyTrash(confirmed: Bool) throws -> FinderResult {
        guard confirmed else { throw FinderControlError.notConfirmed("empty trash") }
        let outcome = AppleScriptSafe.runChecked("tell application \"Finder\" to empty trash")
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Trash emptied")
    }

    /// Eject a mounted volume by name. Requires confirmation.
    public static func eject(name: String, confirmed: Bool) throws -> FinderResult {
        guard confirmed else { throw FinderControlError.notConfirmed("eject \(name)") }
        let esc = AppleScriptSafe.escape(name)
        let outcome = AppleScriptSafe.runChecked("tell application \"Finder\" to eject disk \"\(esc)\"")
        guard outcome.ok else { throw FinderControlError.scriptFailed(outcome.error) }
        return FinderResult(success: true, message: "Ejected \(name)")
    }
}

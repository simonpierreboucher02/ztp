import Foundation
import ZTPProtocols

// MARK: - Catalog types

/// A documented parameter of a tool command.
public struct ParamSpec: Sendable {
    public let name: String
    public let type: String       // string | int | bool | path | json
    public let required: Bool
    public let description: String
    public init(_ name: String, _ type: String, required: Bool = false, _ description: String) {
        self.name = name; self.type = type; self.required = required; self.description = description
    }
}

/// A documented command (the `command` parameter value) of a tool.
public struct CommandSpec: Sendable {
    public let name: String
    public let summary: String
    public let params: [ParamSpec]
    public init(_ name: String, _ summary: String, _ params: [ParamSpec] = []) {
        self.name = name; self.summary = summary; self.params = params
    }
}

/// Documentation for one tool: its commands and their parameters. Powers
/// `ztp schema` and `ztp inspect`, and makes the full option surface
/// discoverable.
public struct ToolDoc: Sendable {
    public let name: String        // canonical, e.g. "ztp-excel"
    public let summary: String
    public let commands: [CommandSpec]
}

// MARK: - Catalog

public enum ToolCatalog {

    /// Shared parameters.
    private static let pInput = ParamSpec("input", "path", required: true, "Path to the input spec/file")
    private static let pOutput = ParamSpec("output", "path", required: true, "Output file path")

    public static func doc(for canonicalName: String) -> ToolDoc? {
        docs[canonicalName]
    }

    public static let docs: [String: ToolDoc] = {
        var d: [String: ToolDoc] = [:]

        d["ztp-excel"] = ToolDoc(name: "ztp-excel", summary: "Generate, inspect and validate XLSX spreadsheets", commands: [
            CommandSpec("build", "Build an XLSX file from a JSON spec", [pInput, pOutput]),
            CommandSpec("validate-spec", "Validate a workbook spec", [pInput]),
            CommandSpec("validate", "Validate an existing XLSX file", [pInput]),
            CommandSpec("inspect", "Inspect an XLSX file (sheets, formulas, styles)", [pInput]),
            CommandSpec("import-csv", "Build an XLSX from a CSV file", [
                pInput, pOutput,
                ParamSpec("sheet", "string", "Sheet name (default Sheet1)"),
                ParamSpec("infer_types", "bool", "Infer numeric/bool types from CSV"),
            ]),
        ])

        d["ztp-docx"] = ToolDoc(name: "ztp-docx", summary: "Generate, inspect and validate DOCX documents", commands: [
            CommandSpec("build", "Build a DOCX file from a JSON spec", [pInput, pOutput]),
            CommandSpec("validate-spec", "Validate a document spec", [pInput]),
            CommandSpec("validate", "Validate an existing DOCX file", [pInput]),
            CommandSpec("inspect", "Inspect a DOCX file", [pInput]),
        ])

        d["ztp-slides"] = ToolDoc(name: "ztp-slides", summary: "Generate, inspect and validate PPTX presentations", commands: [
            CommandSpec("build", "Build a PPTX file from a JSON spec", [pInput, pOutput]),
            CommandSpec("validate-spec", "Validate a presentation spec", [pInput]),
            CommandSpec("validate", "Validate an existing PPTX file", [pInput]),
            CommandSpec("inspect", "Inspect a PPTX file", [pInput]),
        ])

        let pSpec = ParamSpec("spec", "json", "Inline JSON chart spec (alternative to spec_file)")
        let pSpecFile = ParamSpec("spec_file", "path", "Path to a JSON chart spec")
        d["ztp-chart"] = ToolDoc(name: "ztp-chart", summary: "Render charts (PNG/SVG/PDF) from data specs", commands: [
            CommandSpec("build", "Render a chart to a file", [
                pSpec, pSpecFile, pOutput,
                ParamSpec("format", "string", "Output format: png, svg, pdf (default svg)"),
            ]),
            CommandSpec("validate-spec", "Validate a chart spec", [pSpec, pSpecFile]),
            CommandSpec("inspect", "Inspect a chart spec", [pSpec, pSpecFile]),
            CommandSpec("data-summary", "Summarize the chart's data columns", [pSpec, pSpecFile]),
            CommandSpec("themes", "List built-in chart themes", []),
        ])

        d["ztp-mail"] = ToolDoc(name: "ztp-mail", summary: "Draft, preview and send email", commands: [
            CommandSpec("validate", "Validate a mail spec", [pInput]),
            CommandSpec("preview", "Render an HTML/text preview", [pInput, ParamSpec("output", "path", "Optional preview output path")]),
            CommandSpec("draft", "Generate an .eml draft", [pInput, ParamSpec("output", "path", "Output .eml path")]),
            CommandSpec("send", "Send via SMTP (requires confirmed)", [
                pInput,
                ParamSpec("profile", "string", "SMTP profile name (default 'default')"),
                ParamSpec("confirmed", "bool", required: true, "Must be true to actually send"),
            ]),
            CommandSpec("apple-draft", "Create a draft in Apple Mail", [pInput]),
            CommandSpec("inspect", "Inspect an .eml file", [pInput]),
        ])

        d["ztp-message"] = ToolDoc(name: "ztp-message", summary: "Draft and send iMessage/SMS", commands: [
            CommandSpec("validate", "Validate a message spec", [pInput]),
            CommandSpec("preview", "Preview the rendered message", [pInput]),
            CommandSpec("draft", "Generate a message draft (JSON)", [pInput, ParamSpec("output", "path", "Output draft path")]),
            CommandSpec("send", "Send via Messages.app (requires confirmed)", [
                pInput, ParamSpec("confirmed", "bool", required: true, "Must be true to actually send"),
            ]),
            CommandSpec("apple-draft", "Open a draft in Messages.app", [pInput]),
            CommandSpec("templates", "List built-in message templates", []),
            CommandSpec("inspect", "Inspect a message draft", [pInput]),
        ])

        let pURL = ParamSpec("url", "string", required: true, "Target URL (http/https)")
        let viewport = [
            ParamSpec("width", "int", "Viewport width px"),
            ParamSpec("height", "int", "Viewport height px"),
            ParamSpec("scale", "int", "Device scale factor"),
            ParamSpec("timeout_ms", "int", "Navigation timeout in ms"),
        ]
        d["ztp-browser"] = ToolDoc(name: "ztp-browser", summary: "Headless web automation: capture, extract, inspect", commands: [
            CommandSpec("screenshot", "Capture a PNG screenshot", [pURL, pOutput] + viewport),
            CommandSpec("pdf", "Export the page to PDF", [pURL, pOutput] + viewport),
            CommandSpec("html", "Fetch raw HTML", [pURL, ParamSpec("output", "path", "Optional output path")]),
            CommandSpec("text", "Extract readable text", [pURL, ParamSpec("output", "path", "Optional output path")]),
            CommandSpec("links", "Extract links", [pURL]),
            CommandSpec("metadata", "Extract page metadata", [pURL]),
            CommandSpec("inspect", "Full page inspection", [pURL]),
            CommandSpec("open", "Open the URL in Safari", [pURL]),
            CommandSpec("run", "Run a browser task spec", [pInput]),
            CommandSpec("validate-spec", "Validate a browser spec", [pInput]),
            CommandSpec("safari-url", "Get Safari's current URL", []),
            CommandSpec("safari-title", "Get Safari's current page title", []),
        ])

        let path = ParamSpec("path", "path", required: true, "Target file/directory path")
        let confirmed = ParamSpec("confirmed", "bool", required: true, "Must be true for mutating/dangerous ops")
        d["ztp-macos"] = ToolDoc(name: "ztp-macos", summary: "macOS automation: system, files, apps, clipboard, AppleScript", commands: [
            CommandSpec("system-info", "Host, OS, chip, cores, RAM", []),
            CommandSpec("system-disks", "Mounted volumes", []),
            CommandSpec("system-memory", "Memory + process count", []),
            CommandSpec("system-battery", "Battery status", []),
            CommandSpec("finder-reveal", "Reveal a path in Finder", [path]),
            CommandSpec("finder-list", "List a directory", [path]),
            CommandSpec("files-read", "Read a UTF-8 file", [path]),
            CommandSpec("files-write", "Write a file", [path, ParamSpec("content", "string", required: true, "File content"), confirmed]),
            CommandSpec("files-copy", "Copy a file", [ParamSpec("from", "path", required: true, "Source"), path, confirmed]),
            CommandSpec("files-move", "Move/rename a file", [ParamSpec("from", "path", required: true, "Source"), path, confirmed]),
            CommandSpec("files-delete", "Delete a file", [path, confirmed]),
            CommandSpec("files-exists", "Check a path exists", [path]),
            CommandSpec("files-info", "Stat a path", [path]),
            CommandSpec("clipboard-get", "Read the clipboard", []),
            CommandSpec("clipboard-set", "Write the clipboard", [ParamSpec("content", "string", required: true, "Text to copy")]),
            CommandSpec("notify", "Post a notification", [
                ParamSpec("title", "string", required: true, "Title"),
                ParamSpec("body", "string", "Body"),
                ParamSpec("sound", "bool", "Play a sound"),
            ]),
            CommandSpec("screenshot-full", "Capture the full screen", [pOutput]),
            CommandSpec("screenshot-window", "Capture an app window", [ParamSpec("app", "string", required: true, "App name"), pOutput]),
            CommandSpec("apps-open", "Launch an app", [ParamSpec("app", "string", required: true, "App name")]),
            CommandSpec("apps-list", "List installed apps", []),
            CommandSpec("apps-running", "List running apps", []),
            CommandSpec("apps-quit", "Quit an app", [ParamSpec("app", "string", required: true, "App name"), confirmed]),
            CommandSpec("windows-list", "List visible windows", []),
            CommandSpec("processes-list", "List processes", []),
            CommandSpec("processes-inspect", "Filter processes by name", [ParamSpec("name", "string", required: true, "Process name")]),
            CommandSpec("applescript-run", "Run inline AppleScript", [ParamSpec("content", "string", required: true, "Script"), confirmed]),
            CommandSpec("applescript-run-file", "Run an AppleScript file", [path, confirmed]),
            CommandSpec("shortcuts-list", "List Shortcuts", []),
            CommandSpec("shortcuts-run", "Run a Shortcut", [ParamSpec("name", "string", required: true, "Shortcut name"), confirmed]),
            CommandSpec("permissions-check", "Check macOS permissions", []),
        ])

        let confirmFlag = ParamSpec("confirmed", "bool", required: true, "Must be true for mutating/dangerous ops")

        d["ztp-ocr"] = ToolDoc(name: "ztp-ocr", summary: "Local on-device OCR for images, PDFs and screen captures (Vision)", commands: [
            CommandSpec("image", "OCR an image file", [
                ParamSpec("input", "path", required: true, "Image file path"),
                ParamSpec("languages", "string", "Comma-separated languages, e.g. en,fr"),
                ParamSpec("fast", "bool", "Faster, lower-accuracy recognition"),
                ParamSpec("output", "path", "Write extracted text to this file"),
            ]),
            CommandSpec("pdf", "OCR a PDF (rasterizes each page)", [
                ParamSpec("input", "path", required: true, "PDF file path"),
                ParamSpec("pages", "string", "Page range, e.g. 1-3 or 1,2,5"),
                ParamSpec("dpi", "int", "Rasterization DPI (default 200)"),
                ParamSpec("languages", "string", "Comma-separated languages"),
                ParamSpec("output", "path", "Write extracted text to this file"),
            ]),
            CommandSpec("screen", "Capture the screen and OCR it", [
                ParamSpec("languages", "string", "Comma-separated languages"),
                ParamSpec("output", "path", "Write extracted text to this file"),
            ]),
            CommandSpec("languages", "List supported recognition languages", []),
        ])

        d["ztp-notes"] = ToolDoc(name: "ztp-notes", summary: "Read and write Apple Notes", commands: [
            CommandSpec("list", "List notes", [
                ParamSpec("folder", "string", "Restrict to a folder"),
                ParamSpec("limit", "int", "Max notes (default 50)"),
            ]),
            CommandSpec("read", "Read a note by title", [ParamSpec("name", "string", required: true, "Note title")]),
            CommandSpec("create", "Create a note", [
                ParamSpec("title", "string", required: true, "Note title"),
                ParamSpec("body", "string", "Body text or HTML"),
                ParamSpec("folder", "string", "Target folder"),
            ]),
            CommandSpec("append", "Append to a note", [
                ParamSpec("name", "string", required: true, "Note title"),
                ParamSpec("body", "string", required: true, "Text/HTML to append"),
            ]),
            CommandSpec("delete", "Delete a note (to Recently Deleted)", [
                ParamSpec("name", "string", required: true, "Note title"), confirmFlag,
            ]),
            CommandSpec("folders", "List Notes folders", []),
        ])

        let fPath = ParamSpec("path", "path", required: true, "Target path")
        d["ztp-files"] = ToolDoc(name: "ztp-files", summary: "File navigation, search, copy/move/rename and compression", commands: [
            CommandSpec("list", "List a directory", [fPath, ParamSpec("sort", "string", "name|size|date"), ParamSpec("all", "bool", "Include hidden")]),
            CommandSpec("tree", "Recursive tree", [fPath, ParamSpec("depth", "int", "Max depth (default 3)"), ParamSpec("max", "int", "Max entries"), ParamSpec("all", "bool", "Include hidden")]),
            CommandSpec("search", "Search by name or content", [
                fPath, ParamSpec("query", "string", required: true, "Substring or regex"),
                ParamSpec("ext", "string", "Restrict to extension"), ParamSpec("max", "int", "Max results"),
                ParamSpec("regex", "bool", "Treat query as regex"), ParamSpec("content", "bool", "Grep file contents"),
                ParamSpec("all", "bool", "Include hidden"),
            ]),
            CommandSpec("info", "Stat a path", [fPath]),
            CommandSpec("copy", "Copy a file/dir", [ParamSpec("from", "path", required: true, "Source"), ParamSpec("to", "path", required: true, "Destination")]),
            CommandSpec("move", "Move a file/dir", [ParamSpec("from", "path", required: true, "Source"), ParamSpec("to", "path", required: true, "Destination"), confirmFlag]),
            CommandSpec("rename", "Rename a file/dir", [fPath, ParamSpec("name", "string", required: true, "New name"), confirmFlag]),
            CommandSpec("mkdir", "Create a directory", [fPath]),
            CommandSpec("delete", "Delete (to Trash unless permanent)", [fPath, confirmFlag, ParamSpec("permanent", "bool", "Permanently delete")]),
            CommandSpec("compress", "Zip a file/dir", [fPath, ParamSpec("output", "path", required: true, "Output .zip path")]),
            CommandSpec("extract", "Unzip an archive", [ParamSpec("input", "path", required: true, ".zip path"), ParamSpec("to", "path", required: true, "Destination dir"), confirmFlag]),
        ])

        d["ztp-finder"] = ToolDoc(name: "ztp-finder", summary: "Advanced Finder control via AppleScript", commands: [
            CommandSpec("selection", "Get selected items", []),
            CommandSpec("reveal", "Reveal a path", [fPath]),
            CommandSpec("open", "Open a folder/file", [fPath]),
            CommandSpec("new-window", "Open a new Finder window", [ParamSpec("path", "path", "Optional path")]),
            CommandSpec("set-view", "Set window view", [ParamSpec("view", "string", required: true, "icon|list|column|gallery"), ParamSpec("path", "path", "Optional path to open first")]),
            CommandSpec("info", "Finder kind/size for a path", [fPath]),
            CommandSpec("trash", "Move a path to Trash", [fPath, confirmFlag]),
            CommandSpec("empty-trash", "Empty the Trash", [confirmFlag]),
            CommandSpec("eject", "Eject a volume by name", [ParamSpec("name", "string", required: true, "Volume name"), confirmFlag]),
        ])

        return d
    }()

    // MARK: - JSON Schema emission

    /// Emit a JSON-Schema-ish description of a tool's input for `ztp schema`.
    public static func jsonSchema(for canonicalName: String) -> JSONValue? {
        guard let doc = doc(for: canonicalName) else { return nil }
        let commandValues: [JSONValue] = doc.commands.map { cmd in
            let params: [JSONValue] = cmd.params.map { p in
                .object([
                    "name": .string(p.name),
                    "type": .string(p.type),
                    "required": .bool(p.required),
                    "description": .string(p.description),
                ])
            }
            return .object([
                "command": .string(cmd.name),
                "summary": .string(cmd.summary),
                "parameters": .array(params),
            ])
        }
        return .object([
            "tool": .string(doc.name),
            "summary": .string(doc.summary),
            "input": .object([
                "type": .string("object"),
                "required": .array([.string("command")]),
                "note": .string("Pass parameters as a flat JSON object; 'command' selects the operation."),
            ]),
            "commands": .array(commandValues),
        ])
    }
}

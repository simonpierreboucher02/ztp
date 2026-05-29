<div align="center">

# ⚙️ ZTP — Zyquo Tool Protocol

**A native macOS agent-tooling runtime. Generate Office documents, charts, email, messages, and drive the browser & macOS — from JSON, with no Python, no LibreOffice, no Office.**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![Arch](https://img.shields.io/badge/arch-arm64%20%C2%B7%20x86__64-blue)
![Version](https://img.shields.io/badge/version-0.9.0-2F80ED)
![License](https://img.shields.io/badge/license-Apache--2.0-green)
![Notarized](https://img.shields.io/badge/notarized-Developer%20ID-success?logo=apple)

![Tools](https://img.shields.io/badge/tools-12-9D7CFF)
![Tests](https://img.shields.io/badge/tests-278%20passing-4ADE80)
![Source](https://img.shields.io/badge/source-264%20files%20%C2%B7%20~34k%20LOC-7A8693)
![Dependencies](https://img.shields.io/badge/deps-swift--argument--parser%20only-F59E0B)
![Protocol](https://img.shields.io/badge/protocol-ztp%2F1-5BA8FF)

</div>

---

## Table of Contents

- [Why ZTP](#why-ztp)
- [Install](#install)
- [Quick start](#quick-start)
- [The Tool Protocol](#the-tool-protocol)
- [Tool catalog](#tool-catalog)
  - [📊 ztp-excel](#-ztp-excel) · [📝 ztp-docx](#-ztp-docx) · [📑 ztp-slides](#-ztp-slides) · [📈 ztp-chart](#-ztp-chart)
  - [✉️ ztp-mail](#️-ztp-mail) · [💬 ztp-message](#-ztp-message) · [🌐 ztp-browser](#-ztp-browser) · [🖥️ ztp-macos](#️-ztp-macos)
- [Architecture](#architecture)
- [Security model](#security-model)
- [Development](#development)
- [License](#license)

---

## Why ZTP

ZTP is the **execution layer** behind the [Zyquo](https://github.com/simonpierreboucher02/zyquo) AI terminal agent — but it stands alone as a fast, scriptable CLI. Every capability is a **tool** that takes a JSON spec and produces a real artifact:

| | |
|---|---|
| 🚀 **Zero heavyweight deps** | Pure Swift + CoreGraphics/WebKit. No Python, LibreOffice, or Microsoft Office. Only `swift-argument-parser`. |
| 📦 **Real OpenXML** | XLSX / DOCX / PPTX written from scratch (valid, round-trip-inspectable). |
| 🔌 **One protocol** | Every tool implements `ZTPTool`; discover, inspect, validate and run any of them through a single runtime. |
| 🔒 **Safe by default** | AppleScript escaping (no shell), SSRF guards, explicit `--confirm` for destructive ops, notarized binary. |
| ⚡ **Instant** | Cold start < 10 ms; most generators finish in single-digit milliseconds. |

---

## Install

### Homebrew

```bash
brew install simonpierreboucher02/ztp/ztp
# or, from the notarized release tarball (GitHub Releases):
tar xzf ztp-0.9.0-macos-arm64.tar.gz && sudo mv ztp /usr/local/bin/
```

### From source

```bash
git clone https://github.com/simonpierreboucher02/ztp.git
cd ztp
swift build -c release
.build/release/ztp version
```

> **Requirements:** macOS 14+, Swift 6 toolchain (Xcode 16+).

---

## Quick start

```bash
# Discover everything the runtime can do
ztp tools

# Inspect a tool's commands + parameters
ztp inspect excel
ztp schema chart            # machine-readable JSON schema

# Run any tool by name with a JSON input (file or stdin)
echo '{"command":"build","input":"report.json","output":"report.xlsx"}' | ztp run excel

# Or use the dedicated subcommands
ztp excel build report.json --output report.xlsx --json
ztp chart build sales.json --output sales.svg --format svg
ztp validate excel report.json
```

---

## The Tool Protocol

Every tool conforms to a single Swift protocol and is registered in a runtime, so the generic commands work uniformly across all 8 tools:

```swift
public protocol ZTPTool: Sendable {
    var manifest: ToolManifest { get }                 // name, version, capabilities, permissions
    func execute(input: ToolInput, context: ToolContext) async throws -> ToolResult
}
```

| Command | What it does |
|---|---|
| `ztp tools [--json]` | List all registered tools with versions + summaries |
| `ztp run <tool> [input.json] [--command X] [--set k=v]` | Execute any tool; reads a flat JSON params object (file or stdin) |
| `ztp schema <tool>` | Emit the tool's input JSON schema (commands + typed parameters) |
| `ztp inspect <tool>` | Manifest + capabilities + permissions + full command reference |
| `ztp validate <tool> <spec.json>` | Validate a spec against the tool's schema |
| `ztp doctor` · `ztp version` | Environment diagnostics · version/protocol info |

Every result is the same shape: `{ "ok": bool, "tool": "...", "duration_ms": N, "data": {...}, "error": {...} }`.

---

## Tool catalog

| Tool | Purpose | Output |
|------|---------|--------|
| [📊 `ztp-excel`](#-ztp-excel) | Spreadsheets, reports, data tables | `.xlsx` |
| [📝 `ztp-docx`](#-ztp-docx) | Word documents, reports, proposals | `.docx` |
| [📑 `ztp-slides`](#-ztp-slides) | PowerPoint presentations, decks | `.pptx` |
| [📈 `ztp-chart`](#-ztp-chart) | Charts & graphs | `.png` / `.svg` / `.pdf` |
| [✉️ `ztp-mail`](#️-ztp-mail) | Email drafting & sending | `.eml` / SMTP / Apple Mail |
| [💬 `ztp-message`](#-ztp-message) | iMessage / SMS | Messages.app / draft JSON |
| [🌐 `ztp-browser`](#-ztp-browser) | Headless web automation | PNG / PDF / HTML / JSON |
| [🖥️ `ztp-macos`](#️-ztp-macos) | macOS system automation | JSON / files / screenshots |

---

### 📊 ztp-excel

![caps](https://img.shields.io/badge/XLSX-OpenXML-217346) ![feat](https://img.shields.io/badge/merge%20%C2%B7%20freeze%20%C2%B7%20validation%20%C2%B7%20cond--format%20%C2%B7%20comments-2F80ED)

Generate, inspect and validate Excel workbooks.

**Commands:** `build` · `validate-spec` · `validate` · `inspect` · `import-csv` · `sheets` · `preview` · `cell`

**Spec supports:**
- Multiple sheets, cell values (string/number/bool/date), **formulas**, number formats
- Named **styles** (font, fill, alignment), per-cell style refs
- **Merged cells**, **column widths**, **frozen panes**
- **Data validation** — dropdown lists & numeric ranges
- **Conditional formatting** — data bars & 2/3-color scales
- **Cell comments** (notes, via legacy VML drawing)
- CSV import with type inference

```jsonc
{
  "version": "ztp-excel/0.1",
  "workbook": { "title": "Q1 Report" },
  "sheets": [{
    "name": "Sales",
    "freeze": { "rows": 1 },
    "columns": [{ "column": "A", "width": 24 }],
    "merges": ["A1:C1"],
    "validations": [{ "range": "B2:B100", "type": "list", "values": ["Yes","No"] }],
    "conditional_formats": [{ "range": "C2:C100", "type": "data_bar", "color": "5BA8FF" }],
    "comments": [{ "ref": "C1", "author": "Finance", "text": "Growth %" }],
    "cells": [
      { "address": "A1", "value": "Quarterly Report", "style": "header" },
      { "address": "A2", "value": "Jan" }, { "address": "B2", "value": 125000, "format": "currency" },
      { "address": "C2", "formula": "B2/1000" }
    ]
  }]
}
```

```bash
ztp excel build q1.json --output q1.xlsx --json
ztp excel import-csv data.csv --output data.xlsx --inferTypes
```

---

### 📝 ztp-docx

![caps](https://img.shields.io/badge/DOCX-OpenXML-2B579A) ![feat](https://img.shields.io/badge/headers%2Ffooters%20%C2%B7%20page%20numbers%20%C2%B7%20hyperlinks%20%C2%B7%20nested%20lists-2F80ED)

Generate, inspect and validate Word documents.

**Commands:** `build` · `validate-spec` · `validate` · `inspect` · `outline` · `text` · `tables`

**Spec supports:**
- Sections with **headers & footers** (incl. `{page}` → live page number)
- Headings (1-9), paragraphs with rich **runs** (bold/italic/underline/size/font/color)
- **Hyperlinks** (`link` on a run → clickable, styled)
- **Nested bullet/numbered lists** (items as `"text"` or `{ "text", "level" }`, levels 0-8)
- Tables (headers, rows, column widths), images, page breaks, horizontal rules
- Named paragraph/font styles

```jsonc
{
  "version": "ztp-docx/0.1",
  "document": { "title": "Proposal" },
  "sections": [{
    "header": "Acme Corp — Confidential",
    "footer": "Page {page}",
    "elements": [
      { "type": "heading", "level": 1, "text": "Overview" },
      { "type": "paragraph", "runs": [
        { "text": "See " }, { "text": "our site", "link": "https://zyquo.dev" }, { "text": " for details." }
      ]},
      { "type": "bullet_list", "items": ["Top", { "text": "Nested", "level": 1 }] }
    ]
  }]
}
```

---

### 📑 ztp-slides

![caps](https://img.shields.io/badge/PPTX-OpenXML-D24726) ![feat](https://img.shields.io/badge/speaker%20notes%20%C2%B7%20slide%20numbers%20%C2%B7%20transitions-2F80ED)

Generate, inspect and validate PowerPoint presentations.

**Commands:** `build` · `validate-spec` · `validate` · `inspect` · `outline` · `preview` · `text`

**Spec supports:**
- 9 layouts (title, title-content, two-column, image-right/left, table, section-divider, quote, blank)
- Theme (font, accent, background, text color), 16:9 / 4:3
- Content: bullets, numbered lists, tables, images, **KPI cards**, shapes, paragraphs
- **Speaker notes** (rendered to the notes view)
- **Slide numbers** (`presentation.slideNumbers`) and **transitions** (fade/push/wipe/cut/split/cover/zoom)

```jsonc
{
  "version": "ztp-slides/0.1",
  "presentation": { "title": "Q1 Review", "slideNumbers": true },
  "slides": [
    { "layout": "title", "title": "Q1 Review", "transition": "fade",
      "notes": "Greet the audience; mention record quarter." },
    { "layout": "title-content", "title": "Agenda",
      "content": [{ "type": "bullets", "items": ["Results", "Outlook"] }] }
  ]
}
```

---

### 📈 ztp-chart

![caps](https://img.shields.io/badge/render-CoreGraphics%20%C2%B7%20SVG-5EEAD4) ![feat](https://img.shields.io/badge/log%20scale%20%C2%B7%20stacked%20%C2%B7%20data%20labels%20%C2%B7%20axis%20bounds-2F80ED)

Render charts to PNG, SVG or PDF from inline data or CSV.

**Commands:** `build` · `validate-spec` · `inspect` · `data-summary` · `themes`

**Spec supports:**
- Types: line, bar, scatter, area, pie, heatmap, candlestick
- Multi-series, custom colors, legend, gridlines, 7 built-in themes
- **Axis min/max enforcement**, **log scale** (`axis.type: "log"`)
- **Stacked** bars/areas, **data labels** on bars
- Output formats png / svg / pdf

```jsonc
{
  "version": "ztp-chart/0.1",
  "chart": { "type": "bar", "title": "Revenue", "width": 1000, "height": 600 },
  "data": { "values": [{ "q": "Q1", "a": 10, "b": 5 }, { "q": "Q2", "a": 20, "b": 8 }] },
  "x": { "field": "q" }, "y": { "type": "log" },
  "stacked": true, "data_labels": true,
  "series": [{ "field": "a", "label": "Product A" }, { "field": "b", "label": "Product B" }]
}
```

```bash
ztp chart build sales.json --output sales.svg --format svg
ztp chart themes --json
```

---

### ✉️ ztp-mail

![caps](https://img.shields.io/badge/RFC%205322-MIME-7DD3FC) ![feat](https://img.shields.io/badge/SMTP%20%C2%B7%20Apple%20Mail%20%C2%B7%20attachments%20%C2%B7%20inline%20images%20%C2%B7%20priority-2F80ED)

Draft, preview and send email.

**Commands:** `validate` · `preview` · `draft` (.eml) · `send` (SMTP, requires `--confirm`) · `apple-draft` · `inspect`

**Spec supports:**
- from / to / cc / bcc / reply-to, subject, signature
- Body: plain / markdown / html (multipart/alternative)
- **Attachments** (base64, MIME auto-detected, 100 MB cap)
- **Inline images** (`inline_images` → `multipart/related` + `cid:` references)
- **Priority** (high/low → X-Priority/Importance) and **custom headers** (CRLF-injection-guarded)
- SMTP profiles in `~/.ztp/mail/profiles.json`

```jsonc
{
  "version": "ztp-mail/0.1",
  "message": {
    "from": "me@acme.com", "to": ["client@example.com"],
    "subject": "Your report", "priority": "high",
    "headers": { "X-Campaign": "q1" },
    "body": { "type": "markdown", "content": "Hi — see the logo below. <img src=\"cid:logo\">" },
    "inline_images": [{ "path": "logo.png", "cid": "logo" }],
    "attachments": [{ "path": "report.xlsx" }]
  }
}
```

---

### 💬 ztp-message

![caps](https://img.shields.io/badge/iMessage%20%C2%B7%20SMS-Messages.app-34DA50) ![feat](https://img.shields.io/badge/templates%20%C2%B7%20SMS%20limit%20checks-2F80ED)

Draft and send iMessage / SMS via Messages.app.

**Commands:** `validate` · `preview` · `draft` · `send` (requires `--confirm`) · `apple-draft` · `inspect` · `templates`

**Spec supports:**
- Channel (imessage / sms), recipients (name + phone/email)
- Built-in **templates** with `{{variable}}` substitution
- **SMS segmentation warnings** (160 GSM / 70 Unicode) + recipient-type validation
- Safe AppleScript bridge (full escaping, no shell injection)

```jsonc
{
  "version": "ztp-message/0.1",
  "message": {
    "channel": "imessage",
    "to": [{ "name": "Alice", "address": "+15551234567" }],
    "body": { "content": "Report is ready ✅" }
  }
}
```

---

### 🌐 ztp-browser

![caps](https://img.shields.io/badge/WebKit%20%C2%B7%20HTTP%20%C2%B7%20Safari-bridges-FBBF24) ![feat](https://img.shields.io/badge/SSRF%20guard%20%C2%B7%20custom%20headers%20%C2%B7%20wait%20strategies-2F80ED)

Headless web capture & extraction.

**Commands:** `screenshot` · `pdf` · `html` · `text` · `links` · `metadata` · `inspect` · `open` · `run` · `safari`

**Spec supports:**
- WebKit rendering (screenshot / PDF), HTTP fetch (html/text/links/metadata)
- Viewport (width/height/scale), **wait strategies** (dom-ready / network-idle / timeout)
- **Custom HTTP headers** (auth, accept, …)
- **SSRF protection** — private / loopback / link-local / cloud-metadata hosts blocked by default

```jsonc
{
  "version": "ztp-browser/0.1",
  "task": {
    "action": "screenshot", "url": "https://example.com",
    "viewport": { "width": 1440, "height": 900 },
    "wait": { "strategy": "network-idle", "timeout_ms": 8000 },
    "headers": { "Authorization": "Bearer ..." },
    "output": "shot.png"
  }
}
```

```bash
ztp browser screenshot https://example.com --output shot.png
ztp browser text https://example.com
```

---

### 🖥️ ztp-macos

![caps](https://img.shields.io/badge/AppleScript%20%C2%B7%20Process%20%C2%B7%20Files-system-EF4444) ![feat](https://img.shields.io/badge/safe%20escaping%20%C2%B7%20--confirm%20gating-2F80ED)

macOS system automation.

**Categories:** `system-*` (info/disks/memory/battery) · `finder-*` · `files-*` (read/write/copy/move/delete/info/exists) · `clipboard-*` · `notify` · `screenshot-*` · `apps-*` · `windows-list` · `processes-*` · `applescript-*` · `shortcuts-*` · `permissions-check`

- All mutating/destructive ops require `--confirm`
- AppleScript runs via `Process` (no shell), with full string escaping (newline/quote/backslash)

```bash
ztp macos system-info --json
ztp macos files-write /tmp/out.txt --content "hello" --confirm
ztp macos clipboard-get
ztp macos screenshot-full --output screen.png
```

---

### 🔎 ztp-ocr

![caps](https://img.shields.io/badge/Vision%20%C2%B7%20PDFKit-on--device-5EEAD4) ![feat](https://img.shields.io/badge/no%20network-4ADE80)

Local, on-device OCR via Apple's Vision framework — images, scanned PDFs, and live screen captures. No cloud, no network.

**Commands:** `image` · `pdf` · `screen` · `languages`

- `pdf` rasterizes each page (configurable DPI) then recognizes text; supports page ranges (`1-3`, `1,2,5`)
- `--languages en,fr` constrains recognition; `--fast` trades accuracy for speed
- Returns full text plus per-line confidence and bounding boxes; optional `--output` writes the text to a file

```bash
ztp ocr image scan.png --json
ztp ocr pdf invoice.pdf --pages 1-2 --dpi 200 --output invoice.txt
ztp ocr screen --json
ztp ocr languages
```

---

### 🗒️ ztp-notes

![caps](https://img.shields.io/badge/Apple%20Notes-AppleScript-FBBF24) ![feat](https://img.shields.io/badge/safe%20escaping%20%C2%B7%20--confirm%20gating-2F80ED)

Read and write Apple Notes, including structured note creation.

**Commands:** `list` · `read` · `create` · `append` · `delete` · `folders`

- `create` accepts plain text or HTML; the title becomes the note's first line
- `read` returns both raw HTML and a plain-text reduction
- `delete` (to Recently Deleted) requires `--confirm`

```bash
ztp notes list --folder Notes --json
ztp notes create --title "Standup" --body "- shipped OCR\n- next: finder" --json
ztp notes append --name "Standup" --body "- reviewed PRs"
ztp notes read --name "Standup" --json
```

---

### 🗂️ ztp-files

![caps](https://img.shields.io/badge/FileManager%20%C2%B7%20ditto-no%20shell-5EEAD4) ![feat](https://img.shields.io/badge/Trash--safe%20delete%20%C2%B7%20--confirm%20gating-2F80ED)

Filesystem navigation, search, mutation and (de)compression — pure Foundation plus `/usr/bin/ditto` for zip (no shell).

**Commands:** `list` · `tree` · `search` · `info` · `copy` · `move` · `rename` · `mkdir` · `delete` · `compress` · `extract`

- `search` matches by name or, with `--content`, greps file contents; supports `--regex` and `--ext`
- `delete` moves to the Trash by default (recoverable); `--permanent` removes outright; both require `--confirm`
- `move` / `rename` / `extract` require `--confirm`

```bash
ztp files list --path ~/Documents --sort date --json
ztp files search --path ~/src --query "TODO" --content --ext swift --json
ztp files compress --path ~/Project --output ~/project.zip
ztp files delete --path ~/old.txt --confirm
```

---

### 🪟 ztp-finder

![caps](https://img.shields.io/badge/Finder-AppleScript-FBBF24) ![feat](https://img.shields.io/badge/safe%20escaping%20%C2%B7%20--confirm%20gating-2F80ED)

Advanced Finder control via AppleScript.

**Commands:** `selection` · `reveal` · `open` · `new-window` · `set-view` · `info` · `trash` · `empty-trash` · `eject`

- `set-view` switches the front window between `icon` / `list` / `column` / `gallery`
- `selection` returns the POSIX paths of the items currently selected in Finder
- `trash` / `empty-trash` / `eject` require `--confirm`

```bash
ztp finder selection --json
ztp finder set-view --view column --path ~/Downloads
ztp finder reveal --path ~/report.pdf
ztp finder eject --name "Backup" --confirm
```

---

## Architecture

```text
ztp (ZTPCLI)
├── ZTPProtocols     ZTPTool, ToolManifest, ToolInput/Result, JSONValue
├── ZTPCore          ToolRegistry, ZTPRuntime (actor), EventBus, Logger, JSONOutput
├── ZTPExcel  ZTPDocx  ZTPSlides  ZTPChart      ← document & visual generators
├── ZTPMail   ZTPMessage  ZTPBrowser  ZTPMacOS  ← comms, web & system
└── ZTPOCR    ZTPNotes    ZTPFiles    ZTPFinder ← OCR, Apple Notes, files & Finder
```

Each generator owns its **Schema → Model → OpenXML/render → package** pipeline with a dedicated validator. The CLI exposes both per-tool subcommands and the generic protocol commands (`run`/`tools`/`schema`/`inspect`/`validate`).

---

## Security model

- 🔐 **No shell interpolation** for AppleScript — everything goes through `Process` arg arrays with strict escaping.
- 🛡️ **SSRF guard** blocks `127.0.0.1`, `10/8`, `172.16/12`, `192.168/16`, `169.254/16` (incl. cloud metadata), CGNAT, loopback IPv6.
- ✅ **Explicit consent** — `send`, `files-delete`, `applescript-run`, etc. require `--confirm`.
- 🧾 **Header-injection guards** strip CR/LF from mail headers.
- 🍎 **Notarized** Developer ID binary, hardened runtime.

---

## Development

```bash
swift build            # debug
swift test             # 257 tests across 58 suites
swift build -c release # optimized

# Sign + notarize a release (Developer ID + notarytool profile)
./scripts/sign-and-notarize.sh release
./scripts/sign-and-notarize.sh sign
./scripts/sign-and-notarize.sh zip
./scripts/sign-and-notarize.sh notarize
```

---

## License

Apache-2.0 © Simon-Pierre Boucher. Part of the [Zyquo](https://github.com/simonpierreboucher02/zyquo) project.

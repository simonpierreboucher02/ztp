# ZTP — Zyquo Tool Protocol

Native agent runtime infrastructure for macOS. Generate Excel, Word, PowerPoint, and charts from JSON specs — no Python, no LibreOffice, no Microsoft Office required.

Built in Swift 6. Apple Silicon first. Apple notarized.

## Install

```bash
brew tap simonpierreboucher02/ztp
brew install ztp
```

## Tools

### ztp excel — Native XLSX generation

```bash
# Build a spreadsheet from a JSON spec
ztp excel build workbook.json --output report.xlsx --json

# Import CSV to XLSX with type inference
ztp excel import-csv data.csv --output data.xlsx --infer-types --json

# Inspect, preview, validate
ztp excel inspect report.xlsx --json
ztp excel preview report.xlsx --sheet Revenue --rows 20 --json
ztp excel validate report.xlsx --json
```

### ztp docx — Native DOCX generation

```bash
# Build a Word document from a JSON spec
ztp docx build document.json --output report.docx --json

# Inspect, extract text, outline, tables
ztp docx inspect report.docx --json
ztp docx outline report.docx --json
ztp docx text report.docx --json
ztp docx tables report.docx --json
ztp docx validate report.docx --json
```

### ztp slides — Native PPTX generation

```bash
# Build a PowerPoint deck from a JSON spec
ztp slides build deck.json --output deck.pptx --json

# Inspect, outline, preview, extract text
ztp slides inspect deck.pptx --json
ztp slides outline deck.pptx --json
ztp slides preview deck.pptx --json
ztp slides text deck.pptx --json
ztp slides validate deck.pptx --json
```

### ztp chart — Native chart generation

```bash
# Build charts in PNG, SVG, or PDF
ztp chart build chart.json --output chart.png --format png --json
ztp chart build chart.json --output chart.svg --format svg --json
ztp chart build chart.json --output chart.pdf --format pdf --json

# Inspect spec, summarize data, list themes
ztp chart inspect chart.json --json
ztp chart data-summary chart.json --json
ztp chart themes --json
ztp chart validate-spec chart.json --json
```

### ztp mail — Native email drafting and sending

```bash
# Generate .eml draft (default safe mode)
ztp mail draft message.json --output message.eml --json

# Preview as HTML
ztp mail preview message.json --output preview.html --json

# Validate email spec
ztp mail validate message.json --json

# Inspect .eml file
ztp mail inspect message.eml --json

# Create draft in Apple Mail
ztp mail apple-draft message.json --json

# Send via SMTP (requires --confirm)
ztp mail send message.json --smtp-profile work --confirm --json
```

### ztp message — Native iMessage/SMS messaging

```bash
# Preview message
ztp message preview message.json --json

# Generate draft file
ztp message draft message.json --output draft.json --json

# Validate
ztp message validate message.json --json

# Open in Messages.app
ztp message apple-draft message.json --json

# Send (requires --confirm)
ztp message send message.json --confirm --json

# List templates
ztp message templates --json
```

### ztp browser — Native browser automation (WebKit + Safari)

```bash
# Capture screenshot (WebKit, 2x Retina PNG)
ztp browser screenshot https://example.com --output page.png --json

# Export PDF
ztp browser pdf https://example.com --output page.pdf --json

# Extract content (HTTP-based, fast)
ztp browser text https://example.com --json
ztp browser links https://example.com --json
ztp browser metadata https://example.com --json
ztp browser html https://example.com --output page.html --json
ztp browser inspect https://example.com --json

# Safari bridge
ztp browser open https://example.com --json
ztp browser safari current-url --json
ztp browser safari title --json
```

### ztp macos — Native macOS system automation

```bash
# System information
ztp macos system info --json
ztp macos system disks --json
ztp macos system battery --json

# Finder & files
ztp macos finder reveal ~/Documents/report.xlsx --json
ztp macos finder list ~/Desktop --json
ztp macos files read ~/notes.txt --json
ztp macos files copy a.txt b.txt --json

# Clipboard & notifications
ztp macos clipboard get --json
ztp macos clipboard set "Hello" --json
ztp macos notify "Build completed" --json

# Screenshots
ztp macos screenshot full --output screen.png --json
ztp macos screenshot window Safari --output safari.png --json

# Apps & processes
ztp macos apps open Safari --json
ztp macos apps running --json
ztp macos processes list --json

# AppleScript & Shortcuts
ztp macos applescript eval "..." --confirm --json
ztp macos shortcuts list --json
ztp macos shortcuts run "Morning Routine" --confirm --json

# Permissions
ztp macos permissions check --json
```

## JSON Spec Examples

### Excel

```json
{
  "version": "ztp-excel/0.1",
  "workbook": { "title": "Q4 Report", "author": "Zyquo" },
  "sheets": [
    {
      "name": "Revenue",
      "cells": [
        { "address": "A1", "value": "Year", "style": "header" },
        { "address": "B1", "value": "Revenue", "style": "header" },
        { "address": "A2", "value": 2025 },
        { "address": "B2", "value": 150000, "format": "currency" },
        { "address": "B3", "formula": "SUM(B2:B2)", "format": "currency" }
      ]
    }
  ],
  "styles": {
    "header": { "font": { "bold": true, "size": 12 }, "fill": { "color": "D9EAF7" } }
  }
}
```

### Word

```json
{
  "version": "ztp-docx/0.1",
  "document": { "title": "Research Report", "author": "Zyquo" },
  "sections": [
    {
      "elements": [
        { "type": "heading", "level": 1, "text": "Executive Summary" },
        { "type": "paragraph", "text": "Generated by ztp-docx." },
        { "type": "bullet_list", "items": ["Revenue grew 12%", "Margins improved"] },
        { "type": "table", "headers": ["Metric", "Value"], "rows": [["Revenue", "$150K"]] }
      ]
    }
  ]
}
```

### PowerPoint

```json
{
  "version": "ztp-slides/0.1",
  "presentation": { "title": "Business Review", "author": "Zyquo", "size": "16:9" },
  "theme": { "font": "Aptos", "accent": "#3B82F6" },
  "slides": [
    { "layout": "title", "title": "Business Review", "subtitle": "Q4 2026" },
    {
      "layout": "title-content", "title": "Key Points",
      "content": [{ "type": "bullets", "items": ["Revenue +12%", "Margins +6pp"] }]
    },
    {
      "layout": "table", "title": "Metrics",
      "table": { "headers": ["Metric", "Value"], "rows": [["Revenue", "$2.89M"]] }
    }
  ]
}
```

### Chart

```json
{
  "version": "ztp-chart/0.1",
  "chart": { "type": "line", "title": "Revenue Growth", "width": 1200, "height": 700, "theme": "zyquo-light" },
  "data": {
    "values": [
      { "year": 2020, "revenue": 100000 },
      { "year": 2021, "revenue": 120000 },
      { "year": 2022, "revenue": 150000 }
    ]
  },
  "x": { "field": "year", "label": "Year" },
  "y": { "label": "Revenue ($)" },
  "series": [{ "field": "revenue", "label": "Revenue" }],
  "legend": true,
  "grid": true
}
```

Supported chart types: `line`, `bar`, `scatter`, `area`, `pie`, `heatmap`, `candlestick`

Export formats: `png` (2x Retina), `svg`, `pdf` (vector)

Themes: `zyquo-light`, `zyquo-dark`, `finance-light`, `finance-dark`, `research-paper`, `minimal`, `terminal`

### Email

```json
{
  "version": "ztp-mail/0.1",
  "message": {
    "from": "agent@zyquo.dev",
    "to": ["client@example.com"],
    "subject": "Quarterly Report",
    "body": {
      "type": "markdown",
      "content": "Bonjour,\n\n## Points clés\n\n- Revenue **+12%**\n- Margins improved\n\nCordialement,"
    },
    "attachments": [{ "path": "report.xlsx", "name": "Q4_Report.xlsx" }],
    "signature": "-- \nZyquo AI Agent"
  }
}
```

Body types: `plain`, `html`, `markdown` (auto-converted to styled HTML)

### Message

```json
{
  "version": "ztp-message/0.1",
  "message": {
    "channel": "imessage",
    "to": [{ "name": "Alex", "address": "+14185551234" }],
    "body": { "type": "plain", "content": "Confirmation pour demain à 10h." }
  }
}
```

Channels: `imessage`, `sms` (via Messages.app). Built-in templates with `{{variable}}` substitution.

## Agent-Ready JSON Output

Every command supports `--json` for structured machine-readable output:

```json
{
  "ok": true,
  "tool": "ztp-excel",
  "command": "build",
  "output": "report.xlsx",
  "metrics": {
    "duration_ms": 3,
    "sheets": 1,
    "cells_written": 13,
    "file_size_bytes": 7237
  }
}
```

## Architecture

```
ztp/
├── Sources/
│   ├── ZTPCLI/          CLI entry point and commands
│   ├── ZTPCore/         Runtime engine, registry, events
│   ├── ZTPProtocols/    Tool protocol, manifests, contracts
│   ├── ZTPExcel/        XLSX generation (OpenXML + ZIP)
│   ├── ZTPDocx/         DOCX generation (OpenXML + ZIP)
│   ├── ZTPSlides/       PPTX generation (OpenXML + ZIP)
│   ├── ZTPChart/        Chart rendering (CoreGraphics + SVG)
│   ├── ZTPMail/         Email drafting, rendering, SMTP
│   ├── ZTPMessage/      iMessage/SMS via Messages.app
│   ├── ZTPBrowser/      WebKit screenshots, PDF, extraction
│   └── ZTPMacOS/        System, Finder, clipboard, apps, AppleScript
├── Tests/               210 tests across 45 suites
└── Examples/            JSON spec examples
```

## Stats

| | |
|---|---|
| Language | Swift 6 |
| Platform | macOS 14+ / Apple Silicon |
| Binary size | 7.7 MB |
| Dependencies | swift-argument-parser only |
| Source files | 197 |
| Lines of code | ~28,000 |
| Tests | 210 |
| Startup | < 10 ms |

## Runtime Commands

```
ztp version       Show version info
ztp tools         List registered tools
ztp doctor        Check installation health
ztp run           Execute a tool programmatically
ztp validate      Validate manifests and schemas
ztp inspect       Inspect a registered tool
```

## License

MIT

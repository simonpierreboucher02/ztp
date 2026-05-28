// StylesWriter.swift
// ZTPExcel – Generates xl/styles.xml from a StyleRegistry.

import Foundation

/// Produces a valid `xl/styles.xml` document from the registered styles.
struct StylesWriter: Sendable {

    private let registry: StyleRegistry

    init(registry: StyleRegistry) {
        self.registry = registry
    }

    // MARK: - Number format helpers

    /// Built-in format IDs that Excel reserves. Custom formats start at 164.
    private static let builtInFormats: [String: Int] = [
        "general": 0,
    ]

    /// Well-known format aliases mapped to their format strings.
    private static let formatAliases: [String: String] = [
        "currency":   "#,##0.00",
        "percentage": "0.00%",
        "date":       "yyyy-mm-dd",
    ]

    /// Resolves a user-provided format string to either a built-in ID or
    /// a custom format string.
    private static func resolveFormat(_ raw: String) -> String {
        formatAliases[raw.lowercased()] ?? raw
    }

    // MARK: - XML generation

    func toXML() -> String {
        let allStyles = registry.allStyles

        // ---- Collect unique sub-elements ----

        // Fonts: index 0 = default, then one per unique FontStyle.
        var fontList: [FontStyle] = []
        var fontIndex: [FontStyle: Int] = [:]

        // Fills: index 0 = none, index 1 = gray125 (Excel mandatory),
        //        then custom fills.
        var fillList: [FillStyle] = []
        var fillIndex: [FillStyle: Int] = [:]

        // Number formats: custom ones start at ID 164.
        var numFmtList: [(id: Int, code: String)] = []
        var numFmtIndex: [String: Int] = [:]
        var nextNumFmtID = 164

        for (_, style) in allStyles {
            // Fonts
            if let font = style.font, fontIndex[font] == nil {
                let idx = fontList.count + 1 // +1 for default font at 0
                fontIndex[font] = idx
                fontList.append(font)
            }

            // Fills
            if let fill = style.fill, fill.color != nil, fillIndex[fill] == nil {
                let idx = fillList.count + 2 // +2 for none + gray125
                fillIndex[fill] = idx
                fillList.append(fill)
            }

            // Number formats
            if let nf = style.numberFormat {
                let resolved = Self.resolveFormat(nf)
                if numFmtIndex[resolved] == nil {
                    numFmtIndex[resolved] = nextNumFmtID
                    numFmtList.append((id: nextNumFmtID, code: resolved))
                    nextNumFmtID += 1
                }
            }
        }

        // ---- Build XML ----

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\""
        xml += " xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\""
        xml += " mc:Ignorable=\"x14ac\""
        xml += " xmlns:x14ac=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac\">"

        // -- numFmts --
        if !numFmtList.isEmpty {
            xml += "<numFmts count=\"\(numFmtList.count)\">"
            for nf in numFmtList {
                xml += "<numFmt numFmtId=\"\(nf.id)\" formatCode=\"\(XMLEscaping.escape(nf.code))\"/>"
            }
            xml += "</numFmts>"
        }

        // -- fonts --
        let totalFonts = 1 + fontList.count
        xml += "<fonts count=\"\(totalFonts)\" x14ac:knownFonts=\"1\">"
        // Default font
        xml += "<font><sz val=\"11\"/><color theme=\"1\"/><name val=\"Calibri\"/>"
        xml += "<family val=\"2\"/><scheme val=\"minor\"/></font>"
        for font in fontList {
            xml += "<font>"
            if font.bold == true { xml += "<b/>" }
            if font.italic == true { xml += "<i/>" }
            let sz = font.size ?? 11.0
            xml += "<sz val=\"\(formatDouble(sz))\"/>"
            if let color = font.color {
                let argb = color.count == 6 ? "FF\(color)" : color
                xml += "<color rgb=\"\(argb)\"/>"
            } else {
                xml += "<color theme=\"1\"/>"
            }
            xml += "<name val=\"Calibri\"/><family val=\"2\"/><scheme val=\"minor\"/>"
            xml += "</font>"
        }
        xml += "</fonts>"

        // -- fills --
        let totalFills = 2 + fillList.count
        xml += "<fills count=\"\(totalFills)\">"
        xml += "<fill><patternFill patternType=\"none\"/></fill>"
        xml += "<fill><patternFill patternType=\"gray125\"/></fill>"
        for fill in fillList {
            if let color = fill.color {
                let argb = color.count == 6 ? "FF\(color)" : color
                xml += "<fill><patternFill patternType=\"solid\">"
                xml += "<fgColor rgb=\"\(argb)\"/>"
                xml += "<bgColor indexed=\"64\"/>"
                xml += "</patternFill></fill>"
            }
        }
        xml += "</fills>"

        // -- borders --
        xml += "<borders count=\"1\">"
        xml += "<border><left/><right/><top/><bottom/><diagonal/></border>"
        xml += "</borders>"

        // -- cellStyleXfs --
        xml += "<cellStyleXfs count=\"1\">"
        xml += "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/>"
        xml += "</cellStyleXfs>"

        // -- cellXfs --
        // Index 0 = default xf, then one per registered style (by ID order).
        let totalXfs = 1 + allStyles.count
        xml += "<cellXfs count=\"\(totalXfs)\">"
        // Default xf (index 0)
        xml += "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>"

        for (_, style) in allStyles {
            let fIdx = style.font.flatMap { fontIndex[$0] } ?? 0
            let fiIdx = style.fill.flatMap { fillIndex[$0] } ?? 0
            let nfId: Int
            if let nf = style.numberFormat {
                let resolved = Self.resolveFormat(nf)
                nfId = numFmtIndex[resolved] ?? 0
            } else {
                nfId = 0
            }

            xml += "<xf numFmtId=\"\(nfId)\" fontId=\"\(fIdx)\" fillId=\"\(fiIdx)\" borderId=\"0\" xfId=\"0\""

            if nfId != 0 { xml += " applyNumberFormat=\"1\"" }
            if fIdx != 0 { xml += " applyFont=\"1\"" }
            if fiIdx != 0 { xml += " applyFill=\"1\"" }

            if let align = style.alignment,
               (align.horizontal != nil || align.vertical != nil || align.wrapText == true) {
                xml += " applyAlignment=\"1\">"
                xml += "<alignment"
                if let h = align.horizontal { xml += " horizontal=\"\(h.rawValue)\"" }
                if let v = align.vertical { xml += " vertical=\"\(v.rawValue)\"" }
                if align.wrapText == true { xml += " wrapText=\"1\"" }
                xml += "/>"
                xml += "</xf>"
            } else {
                xml += "/>"
            }
        }
        xml += "</cellXfs>"

        // -- cellStyles --
        xml += "<cellStyles count=\"1\">"
        xml += "<cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/>"
        xml += "</cellStyles>"

        // -- dxfs --
        xml += "<dxfs count=\"0\"/>"

        // -- tableStyles --
        xml += "<tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium2\""
        xml += " defaultPivotStyle=\"PivotStyleLight16\"/>"

        xml += "</styleSheet>"
        return xml
    }

    // MARK: - Helpers

    /// Formats a double, stripping ".0" for whole numbers.
    private func formatDouble(_ value: Double) -> String {
        if value == value.rounded() && value >= 0 && value < 1_000_000 {
            return String(Int(value))
        }
        return String(value)
    }
}

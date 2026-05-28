// XLSXPackager.swift
// ZTPExcel – Assembles all OpenXML parts into a complete .xlsx file.

import Foundation

/// Assembles the individual XML parts of an XLSX document and packages
/// them into a ZIP archive that constitutes a valid .xlsx file.
public struct XLSXPackager: Sendable {

    /// Errors that can occur during packaging.
    enum PackagingError: Error, Sendable {
        case xmlEncodingFailed(part: String)
    }

    /// Builds a complete .xlsx file from the internal workbook model.
    ///
    /// - Parameters:
    ///   - workbook: The workbook containing sheets and metadata.
    ///   - styleRegistry: The registry of named styles.
    /// - Returns: The raw bytes of the XLSX (ZIP) file.
    /// - Throws: If XML encoding or ZIP creation fails.
    public static func package(
        workbook: Workbook,
        styleRegistry: StyleRegistry
    ) throws -> Data {

        var entries: [ZIPWriter.Entry] = []
        var sharedStrings = SharedStringTable()

        let sheetNames = workbook.sheets.map(\.name)
        let sheetCount = workbook.sheets.count

        // ---- Generate worksheet XML (must come first to populate shared strings) ----

        var sheetXMLs: [String] = []
        for sheet in workbook.sheets {
            let xml = WorksheetWriter.toXML(
                worksheet: sheet,
                sharedStrings: &sharedStrings,
                styleRegistry: styleRegistry
            )
            sheetXMLs.append(xml)
        }

        let hasSharedStrings = sharedStrings.count > 0

        // ---- Assemble all ZIP entries ----

        // [Content_Types].xml
        let contentTypesXML = ContentTypesWriter.toXML(
            sheetCount: sheetCount,
            hasSharedStrings: hasSharedStrings
        )
        try entries.append(xmlEntry(path: "[Content_Types].xml", xml: contentTypesXML))

        // _rels/.rels
        let rootRelsXML = RelsWriter.rootRelsXML()
        try entries.append(xmlEntry(path: "_rels/.rels", xml: rootRelsXML))

        // xl/workbook.xml
        let wbXML = WorkbookWriter.workbookXML(sheetNames: sheetNames)
        try entries.append(xmlEntry(path: "xl/workbook.xml", xml: wbXML))

        // xl/_rels/workbook.xml.rels
        let wbRelsXML = WorkbookWriter.workbookRelsXML(
            sheetCount: sheetCount,
            hasSharedStrings: hasSharedStrings
        )
        try entries.append(xmlEntry(path: "xl/_rels/workbook.xml.rels", xml: wbRelsXML))

        // xl/styles.xml
        let stylesWriter = StylesWriter(registry: styleRegistry)
        let stylesXML = stylesWriter.toXML()
        try entries.append(xmlEntry(path: "xl/styles.xml", xml: stylesXML))

        // xl/worksheets/sheet{N}.xml
        for (i, sheetXML) in sheetXMLs.enumerated() {
            try entries.append(xmlEntry(
                path: "xl/worksheets/sheet\(i + 1).xml",
                xml: sheetXML
            ))
        }

        // xl/sharedStrings.xml (only if there are strings)
        if hasSharedStrings {
            let ssXML = sharedStrings.toXML()
            try entries.append(xmlEntry(path: "xl/sharedStrings.xml", xml: ssXML))
        }

        // docProps/core.xml
        let coreXML = DocPropsWriter.coreXML(
            title: workbook.title,
            author: workbook.author
        )
        try entries.append(xmlEntry(path: "docProps/core.xml", xml: coreXML))

        // docProps/app.xml
        let appXML = DocPropsWriter.appXML()
        try entries.append(xmlEntry(path: "docProps/app.xml", xml: appXML))

        // ---- Create ZIP ----

        return try ZIPWriter.createArchive(entries: entries)
    }

    // MARK: - Helpers

    /// Converts an XML string to a ZIP entry, failing if UTF-8 encoding
    /// is not possible.
    private static func xmlEntry(path: String, xml: String) throws -> ZIPWriter.Entry {
        guard let data = xml.data(using: .utf8) else {
            throw PackagingError.xmlEncodingFailed(part: path)
        }
        return ZIPWriter.Entry(path: path, data: data)
    }
}

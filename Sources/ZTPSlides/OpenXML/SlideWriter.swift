// SlideWriter.swift
// ZTPSlides – Generates individual slide XML for a PPTX package.

import Foundation

/// Produces the XML for a single slide (`ppt/slides/slideN.xml`).
///
/// Handles layout-based positioning and rendering of all element types
/// including text boxes, images, tables, shapes, and KPI cards.
public struct SlideWriter: Sendable {

    // MARK: - Layout Constants (EMU)

    /// Horizontal margin from the slide edges.
    private static let margin: Int64 = 838_200

    /// Width of the content area (slide width minus two margins).
    private static func contentWidth(_ size: SlideSize) -> Int64 {
        size.width - 2 * margin
    }

    // -- Title slide layout --
    private static let titleSlide_titleX: Int64 = 1_524_000
    private static let titleSlide_titleY: Int64 = 2_286_000
    private static let titleSlide_titleW: Int64 = 9_144_000
    private static let titleSlide_titleH: Int64 = 1_325_563
    private static let titleSlide_subtitleY: Int64 = 3_611_563
    private static let titleSlide_subtitleH: Int64 = 914_400

    // -- Title-content and generic layouts --
    private static let titleY: Int64 = 365_125
    private static let titleH: Int64 = 914_400
    private static let contentY: Int64 = 1_524_000
    private static let contentH: Int64 = 4_876_800

    // -- Font sizes in hundredths of a point --
    private static let titleFontSize = 3600     // 36pt
    private static let titleSlideFontSize = 4400  // 44pt
    private static let subtitleFontSize = 2400  // 24pt
    private static let bodyFontSize = 1800      // 18pt
    private static let bulletFontSize = 1600    // 16pt
    private static let tableFontSize = 1400     // 14pt
    private static let kpiValueFontSize = 4000  // 40pt
    private static let kpiLabelFontSize = 1400  // 14pt
    private static let kpiDeltaFontSize = 1200  // 12pt

    // MARK: - Public API

    /// Generates the full slide XML for one slide.
    ///
    /// - Parameters:
    ///   - slide: The slide model.
    ///   - slideIndex: Zero-based slide index.
    ///   - theme: The presentation theme.
    ///   - size: The slide dimensions in EMU.
    ///   - imageRelationships: Mapping of image file paths to their rId
    ///     references in the slide relationships file.
    /// - Returns: The complete XML string.
    public static func toXML(
        slide: PptxSlide,
        slideIndex: Int,
        theme: PptxTheme,
        size: SlideSize,
        imageRelationships: [String: String]
    ) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<p:sld"
        xml += " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\""
        xml += " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        xml += " xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"

        xml += "<p:cSld>"

        // Background fill if theme specifies a background color
        if let bg = theme.background {
            xml += "<p:bg><p:bgPr>"
            xml += "<a:solidFill><a:srgbClr val=\"\(bg)\"/></a:solidFill>"
            xml += "<a:effectLst/>"
            xml += "</p:bgPr></p:bg>"
        }

        xml += "<p:spTree>"
        xml += "<p:nvGrpSpPr>"
        xml += "<p:cNvPr id=\"1\" name=\"\"/>"
        xml += "<p:cNvGrpSpPr/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvGrpSpPr>"
        xml += "<p:grpSpPr/>"

        // Shape ID counter (starts at 2 since id=1 is used by the group)
        var nextId = 2

        let cw = contentWidth(size)

        switch slide.layout {
        case .title, .sectionDivider:
            // Title centered on slide
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: titleSlide_titleX, y: titleSlide_titleY,
                    cx: titleSlide_titleW, cy: titleSlide_titleH,
                    text: titleText, fontSize: titleSlideFontSize,
                    bold: true, alignment: "ctr",
                    fontColor: theme.textColor
                )
                nextId += 1
            }
            // Subtitle below title
            if let subtitleText = slide.subtitle {
                xml += textBoxXML(
                    id: nextId, name: "Subtitle",
                    x: titleSlide_titleX, y: titleSlide_subtitleY,
                    cx: titleSlide_titleW, cy: titleSlide_subtitleH,
                    text: subtitleText, fontSize: subtitleFontSize,
                    bold: false, alignment: "ctr",
                    fontColor: theme.textColor
                )
                nextId += 1
            }
            // Render any additional content elements below
            var cursorY = titleSlide_subtitleY + titleSlide_subtitleH + 228_600
            for element in slide.content {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: margin, y: cursorY,
                    cx: cw, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                cursorY += rendered.height + 114_300
            }

        case .titleContent, .twoColumn:
            // Title at top
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: margin, y: titleY,
                    cx: cw, cy: titleH,
                    text: titleText, fontSize: titleFontSize,
                    bold: true, alignment: "l",
                    fontColor: theme.textColor
                )
                nextId += 1
            }

            if slide.layout == .twoColumn {
                // Split content into two columns
                let colWidth = (cw - 457_200) / 2  // gap between columns
                let leftElements = slide.content.prefix(slide.content.count / 2 + slide.content.count % 2)
                let rightElements = slide.content.suffix(slide.content.count / 2)

                var leftY = contentY
                for element in leftElements {
                    let rendered = renderElement(
                        element, id: &nextId,
                        x: margin, y: leftY,
                        cx: colWidth, theme: theme, size: size,
                        imageRelationships: imageRelationships
                    )
                    xml += rendered.xml
                    leftY += rendered.height + 114_300
                }

                var rightY = contentY
                for element in rightElements {
                    let rendered = renderElement(
                        element, id: &nextId,
                        x: margin + colWidth + 457_200, y: rightY,
                        cx: colWidth, theme: theme, size: size,
                        imageRelationships: imageRelationships
                    )
                    xml += rendered.xml
                    rightY += rendered.height + 114_300
                }
            } else {
                // Single content area
                var cursorY = contentY
                for element in slide.content {
                    let rendered = renderElement(
                        element, id: &nextId,
                        x: margin, y: cursorY,
                        cx: cw, theme: theme, size: size,
                        imageRelationships: imageRelationships
                    )
                    xml += rendered.xml
                    cursorY += rendered.height + 114_300
                }
            }

        case .imageRight, .imageLeft:
            // Title at top
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: margin, y: titleY,
                    cx: cw, cy: titleH,
                    text: titleText, fontSize: titleFontSize,
                    bold: true, alignment: "l",
                    fontColor: theme.textColor
                )
                nextId += 1
            }

            let halfWidth = (cw - 457_200) / 2
            let leftX = margin
            let rightX = margin + halfWidth + 457_200

            // Separate images from non-images
            var textElements: [PptxElement] = []
            var imageElements: [PptxElement] = []
            for element in slide.content {
                if case .image = element {
                    imageElements.append(element)
                } else {
                    textElements.append(element)
                }
            }

            let textX = slide.layout == .imageRight ? leftX : rightX
            let imgX = slide.layout == .imageRight ? rightX : leftX

            var textY = contentY
            for element in textElements {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: textX, y: textY,
                    cx: halfWidth, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                textY += rendered.height + 114_300
            }

            var imgY = contentY
            for element in imageElements {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: imgX, y: imgY,
                    cx: halfWidth, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                imgY += rendered.height + 114_300
            }

        case .table:
            // Title at top, table below
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: margin, y: titleY,
                    cx: cw, cy: titleH,
                    text: titleText, fontSize: titleFontSize,
                    bold: true, alignment: "l",
                    fontColor: theme.textColor
                )
                nextId += 1
            }

            var cursorY = contentY
            for element in slide.content {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: margin, y: cursorY,
                    cx: cw, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                cursorY += rendered.height + 114_300
            }

        case .quote:
            // Title at top
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: margin, y: titleY,
                    cx: cw, cy: titleH,
                    text: titleText, fontSize: titleFontSize,
                    bold: true, alignment: "l",
                    fontColor: theme.textColor
                )
                nextId += 1
            }

            // Render content centered with italic styling
            var cursorY = contentY + 457_200
            for element in slide.content {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: margin + 914_400, y: cursorY,
                    cx: cw - 1_828_800, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                cursorY += rendered.height + 114_300
            }

        case .blank:
            // Stack elements vertically from top
            var cursorY: Int64 = margin
            if let titleText = slide.title {
                xml += textBoxXML(
                    id: nextId, name: "Title",
                    x: margin, y: cursorY,
                    cx: cw, cy: titleH,
                    text: titleText, fontSize: titleFontSize,
                    bold: true, alignment: "l",
                    fontColor: theme.textColor
                )
                nextId += 1
                cursorY += titleH + 114_300
            }
            for element in slide.content {
                let rendered = renderElement(
                    element, id: &nextId,
                    x: margin, y: cursorY,
                    cx: cw, theme: theme, size: size,
                    imageRelationships: imageRelationships
                )
                xml += rendered.xml
                cursorY += rendered.height + 114_300
            }
        }

        xml += "</p:spTree>"
        xml += "</p:cSld>"
        xml += "</p:sld>"
        return xml
    }

    // MARK: - Element Rendering

    /// Result of rendering a single element, including the XML and the
    /// vertical space it occupies (for stacking).
    private struct RenderResult {
        let xml: String
        let height: Int64
    }

    /// Renders a single `PptxElement` to its OpenXML shape representation.
    private static func renderElement(
        _ element: PptxElement,
        id: inout Int,
        x: Int64, y: Int64, cx: Int64,
        theme: PptxTheme,
        size: SlideSize,
        imageRelationships: [String: String]
    ) -> RenderResult {
        switch element {
        case .title(let text):
            let h: Int64 = 685_800
            let xml = textBoxXML(
                id: id, name: "Title",
                x: x, y: y, cx: cx, cy: h,
                text: text, fontSize: titleFontSize,
                bold: true, alignment: "l",
                fontColor: theme.textColor
            )
            id += 1
            return RenderResult(xml: xml, height: h)

        case .subtitle(let text):
            let h: Int64 = 457_200
            let xml = textBoxXML(
                id: id, name: "Subtitle",
                x: x, y: y, cx: cx, cy: h,
                text: text, fontSize: subtitleFontSize,
                bold: false, alignment: "l",
                fontColor: theme.textColor
            )
            id += 1
            return RenderResult(xml: xml, height: h)

        case .paragraph(let text, _):
            let lineCount = max(1, text.count / 80 + 1)
            let h = Int64(lineCount) * 274_320 + 91_440
            let xml = textBoxXML(
                id: id, name: "TextBox",
                x: x, y: y, cx: cx, cy: h,
                text: text, fontSize: bodyFontSize,
                bold: false, alignment: "l",
                fontColor: theme.textColor
            )
            id += 1
            return RenderResult(xml: xml, height: h)

        case .bullets(let items):
            let h = Int64(items.count) * 274_320 + 91_440
            let xml = bulletListXML(
                id: id, name: "Bullets",
                x: x, y: y, cx: cx, cy: h,
                items: items, numbered: false,
                fontColor: theme.textColor
            )
            id += 1
            return RenderResult(xml: xml, height: h)

        case .numberedList(let items):
            let h = Int64(items.count) * 274_320 + 91_440
            let xml = bulletListXML(
                id: id, name: "NumberedList",
                x: x, y: y, cx: cx, cy: h,
                items: items, numbered: true,
                fontColor: theme.textColor
            )
            id += 1
            return RenderResult(xml: xml, height: h)

        case .image(let img):
            let imgW = Int64(img.width ?? Int(cx))
            let imgH = Int64(img.height ?? Int(cx * 3 / 4))
            var totalH = imgH

            guard let rId = imageRelationships[img.path] else {
                // If the image has no rId, skip it
                return RenderResult(xml: "", height: 0)
            }

            var xml = imageXML(
                id: id, name: "Image",
                x: x, y: y, cx: imgW, cy: imgH,
                rId: rId
            )
            id += 1

            // Caption below image
            if let caption = img.caption, !caption.isEmpty {
                let captionH: Int64 = 274_320
                xml += textBoxXML(
                    id: id, name: "Caption",
                    x: x, y: y + imgH + 57_150,
                    cx: imgW, cy: captionH,
                    text: caption, fontSize: kpiLabelFontSize,
                    bold: false, alignment: "ctr",
                    fontColor: theme.textColor
                )
                id += 1
                totalH += captionH + 57_150
            }

            return RenderResult(xml: xml, height: totalH)

        case .table(let tbl):
            let colCount = tbl.columnCount
            guard colCount > 0 else {
                return RenderResult(xml: "", height: 0)
            }
            let rowCount = tbl.rows.count + (tbl.headers != nil ? 1 : 0)
            let rowH: Int64 = 370_840
            let tableH = Int64(rowCount) * rowH
            let xml = tableXML(
                id: id, name: "Table",
                x: x, y: y, cx: cx, cy: tableH,
                table: tbl, theme: theme
            )
            id += 1
            return RenderResult(xml: xml, height: tableH)

        case .shape(let shp):
            let shpW = Int64(shp.width ?? Int(cx))
            let shpH = Int64(shp.height ?? 914_400)
            let xml = shapeXML(
                id: id, name: "Shape",
                x: x, y: y, cx: shpW, cy: shpH,
                shape: shp, theme: theme
            )
            id += 1
            return RenderResult(xml: xml, height: shpH)

        case .kpi(let label, let value, let delta):
            let cardH: Int64 = 1_600_200
            let cardW = min(cx, 3_657_600)
            let xml = kpiCardXML(
                id: &id, name: "KPI",
                x: x, y: y, cx: cardW, cy: cardH,
                label: label, value: value, delta: delta,
                theme: theme
            )
            return RenderResult(xml: xml, height: cardH)

        case .spacer(let height):
            let h = Int64(height ?? 457_200)
            return RenderResult(xml: "", height: h)
        }
    }

    // MARK: - Text Box

    /// Generates a text box `<p:sp>` element.
    private static func textBoxXML(
        id: Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        text: String, fontSize: Int,
        bold: Bool, alignment: String,
        fontColor: String?
    ) -> String {
        let esc = SlidesXMLEscaping.escape
        let bAttr = bold ? " b=\"1\"" : ""
        var colorRun = ""
        if let fc = fontColor {
            colorRun = "<a:solidFill><a:srgbClr val=\"\(fc)\"/></a:solidFill>"
        }

        var xml = "<p:sp>"
        xml += "<p:nvSpPr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvSpPr txBox=\"1\"/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvSpPr>"
        xml += "<p:spPr>"
        xml += "<a:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</a:xfrm>"
        xml += "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
        xml += "<a:noFill/>"
        xml += "</p:spPr>"
        xml += "<p:txBody>"
        xml += "<a:bodyPr wrap=\"square\" rtlCol=\"0\"/>"
        xml += "<a:lstStyle/>"
        xml += "<a:p>"
        xml += "<a:pPr algn=\"\(alignment)\"/>"
        xml += "<a:r>"
        xml += "<a:rPr lang=\"en-US\" sz=\"\(fontSize)\"\(bAttr) dirty=\"0\">"
        xml += colorRun
        xml += "</a:rPr>"
        xml += "<a:t>\(esc(text))</a:t>"
        xml += "</a:r>"
        xml += "</a:p>"
        xml += "</p:txBody>"
        xml += "</p:sp>"
        return xml
    }

    // MARK: - Bullet / Numbered List

    /// Generates a text box with bullet or numbered list paragraphs.
    private static func bulletListXML(
        id: Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        items: [String], numbered: Bool,
        fontColor: String?
    ) -> String {
        let esc = SlidesXMLEscaping.escape
        var colorRun = ""
        if let fc = fontColor {
            colorRun = "<a:solidFill><a:srgbClr val=\"\(fc)\"/></a:solidFill>"
        }

        var xml = "<p:sp>"
        xml += "<p:nvSpPr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvSpPr txBox=\"1\"/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvSpPr>"
        xml += "<p:spPr>"
        xml += "<a:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</a:xfrm>"
        xml += "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
        xml += "<a:noFill/>"
        xml += "</p:spPr>"
        xml += "<p:txBody>"
        xml += "<a:bodyPr wrap=\"square\" rtlCol=\"0\"/>"
        xml += "<a:lstStyle/>"

        for (index, item) in items.enumerated() {
            xml += "<a:p>"
            xml += "<a:pPr marL=\"342900\" indent=\"-342900\">"
            if numbered {
                xml += "<a:buAutoNum type=\"arabicPeriod\" startAt=\"\(index + 1)\"/>"
            } else {
                xml += "<a:buChar char=\"\u{2022}\"/>"
            }
            xml += "</a:pPr>"
            xml += "<a:r>"
            xml += "<a:rPr lang=\"en-US\" sz=\"\(bulletFontSize)\" dirty=\"0\">"
            xml += colorRun
            xml += "</a:rPr>"
            xml += "<a:t>\(esc(item))</a:t>"
            xml += "</a:r>"
            xml += "</a:p>"
        }

        xml += "</p:txBody>"
        xml += "</p:sp>"
        return xml
    }

    // MARK: - Image

    /// Generates a picture `<p:pic>` element.
    private static func imageXML(
        id: Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        rId: String
    ) -> String {
        let esc = SlidesXMLEscaping.escape

        var xml = "<p:pic>"
        xml += "<p:nvPicPr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr>"
        xml += "<p:nvPr/>"
        xml += "</p:nvPicPr>"
        xml += "<p:blipFill>"
        xml += "<a:blip r:embed=\"\(rId)\"/>"
        xml += "<a:stretch><a:fillRect/></a:stretch>"
        xml += "</p:blipFill>"
        xml += "<p:spPr>"
        xml += "<a:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</a:xfrm>"
        xml += "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
        xml += "</p:spPr>"
        xml += "</p:pic>"
        return xml
    }

    // MARK: - Table

    /// Generates a table inside a `<p:graphicFrame>`.
    private static func tableXML(
        id: Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        table: PptxTable, theme: PptxTheme
    ) -> String {
        let esc = SlidesXMLEscaping.escape
        let colCount = table.columnCount
        guard colCount > 0 else { return "" }
        let colWidth = cx / Int64(colCount)
        let rowH: Int64 = 370_840
        let accent = theme.accent

        var xml = "<p:graphicFrame>"
        xml += "<p:nvGraphicFramePr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp=\"1\"/></p:cNvGraphicFramePr>"
        xml += "<p:nvPr/>"
        xml += "</p:nvGraphicFramePr>"
        xml += "<p:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</p:xfrm>"

        xml += "<a:graphic>"
        xml += "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\">"
        xml += "<a:tbl>"
        xml += "<a:tblPr firstRow=\"1\" bandRow=\"1\">"
        xml += "<a:tblStyle styleId=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>"
        xml += "</a:tblPr>"

        // Column grid
        xml += "<a:tblGrid>"
        for _ in 0..<colCount {
            xml += "<a:gridCol w=\"\(colWidth)\"/>"
        }
        xml += "</a:tblGrid>"

        // Header row
        if let headers = table.headers {
            xml += "<a:tr h=\"\(rowH)\">"
            for header in headers {
                xml += "<a:tc>"
                xml += "<a:txBody>"
                xml += "<a:bodyPr/>"
                xml += "<a:lstStyle/>"
                xml += "<a:p>"
                xml += "<a:r>"
                xml += "<a:rPr lang=\"en-US\" sz=\"\(tableFontSize)\" b=\"1\" dirty=\"0\">"
                xml += "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>"
                xml += "</a:rPr>"
                xml += "<a:t>\(esc(header))</a:t>"
                xml += "</a:r>"
                xml += "</a:p>"
                xml += "</a:txBody>"
                xml += "<a:tcPr>"
                xml += "<a:solidFill><a:srgbClr val=\"\(accent)\"/></a:solidFill>"
                xml += "</a:tcPr>"
                xml += "</a:tc>"
            }
            xml += "</a:tr>"
        }

        // Data rows
        for row in table.rows {
            xml += "<a:tr h=\"\(rowH)\">"
            for colIdx in 0..<colCount {
                let cellText = colIdx < row.count ? row[colIdx] : ""
                xml += "<a:tc>"
                xml += "<a:txBody>"
                xml += "<a:bodyPr/>"
                xml += "<a:lstStyle/>"
                xml += "<a:p>"
                xml += "<a:r>"
                xml += "<a:rPr lang=\"en-US\" sz=\"\(tableFontSize)\" dirty=\"0\"/>"
                xml += "<a:t>\(esc(cellText))</a:t>"
                xml += "</a:r>"
                xml += "</a:p>"
                xml += "</a:txBody>"
                xml += "<a:tcPr/>"
                xml += "</a:tc>"
            }
            xml += "</a:tr>"
        }

        xml += "</a:tbl>"
        xml += "</a:graphicData>"
        xml += "</a:graphic>"
        xml += "</p:graphicFrame>"
        return xml
    }

    // MARK: - Shape

    /// Generates a shape `<p:sp>` element.
    private static func shapeXML(
        id: Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        shape: PptxShape, theme: PptxTheme
    ) -> String {
        let esc = SlidesXMLEscaping.escape
        let prst = shape.type.rawValue

        var xml = "<p:sp>"
        xml += "<p:nvSpPr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvSpPr/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvSpPr>"
        xml += "<p:spPr>"
        xml += "<a:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</a:xfrm>"
        xml += "<a:prstGeom prst=\"\(esc(prst))\"><a:avLst/></a:prstGeom>"

        // Fill
        if let fill = shape.fillColor {
            xml += "<a:solidFill><a:srgbClr val=\"\(fill)\"/></a:solidFill>"
        } else {
            xml += "<a:noFill/>"
        }

        // Border
        if let border = shape.borderColor {
            xml += "<a:ln w=\"12700\"><a:solidFill><a:srgbClr val=\"\(border)\"/></a:solidFill></a:ln>"
        }

        xml += "</p:spPr>"

        // Text inside shape
        if let text = shape.text, !text.isEmpty {
            var colorRun = ""
            if let tc = theme.textColor {
                colorRun = "<a:solidFill><a:srgbClr val=\"\(tc)\"/></a:solidFill>"
            }
            xml += "<p:txBody>"
            xml += "<a:bodyPr wrap=\"square\" rtlCol=\"0\" anchor=\"ctr\"/>"
            xml += "<a:lstStyle/>"
            xml += "<a:p>"
            xml += "<a:pPr algn=\"ctr\"/>"
            xml += "<a:r>"
            xml += "<a:rPr lang=\"en-US\" sz=\"\(bodyFontSize)\" dirty=\"0\">"
            xml += colorRun
            xml += "</a:rPr>"
            xml += "<a:t>\(esc(text))</a:t>"
            xml += "</a:r>"
            xml += "</a:p>"
            xml += "</p:txBody>"
        }

        xml += "</p:sp>"
        return xml
    }

    // MARK: - KPI Card

    /// Generates a KPI card as a rounded rectangle with label, value, and
    /// optional delta text arranged vertically.
    private static func kpiCardXML(
        id: inout Int, name: String,
        x: Int64, y: Int64, cx: Int64, cy: Int64,
        label: String, value: String, delta: String?,
        theme: PptxTheme
    ) -> String {
        let esc = SlidesXMLEscaping.escape
        let accent = theme.accent

        var xml = "<p:sp>"
        xml += "<p:nvSpPr>"
        xml += "<p:cNvPr id=\"\(id)\" name=\"\(esc(name)) \(id)\"/>"
        xml += "<p:cNvSpPr/>"
        xml += "<p:nvPr/>"
        xml += "</p:nvSpPr>"
        xml += "<p:spPr>"
        xml += "<a:xfrm>"
        xml += "<a:off x=\"\(x)\" y=\"\(y)\"/>"
        xml += "<a:ext cx=\"\(cx)\" cy=\"\(cy)\"/>"
        xml += "</a:xfrm>"
        xml += "<a:prstGeom prst=\"roundRect\"><a:avLst/></a:prstGeom>"
        xml += "<a:solidFill><a:srgbClr val=\"\(accent)\"/></a:solidFill>"
        xml += "</p:spPr>"
        xml += "<p:txBody>"
        xml += "<a:bodyPr wrap=\"square\" rtlCol=\"0\" anchor=\"ctr\"/>"
        xml += "<a:lstStyle/>"

        // Label
        xml += "<a:p>"
        xml += "<a:pPr algn=\"ctr\"/>"
        xml += "<a:r>"
        xml += "<a:rPr lang=\"en-US\" sz=\"\(kpiLabelFontSize)\" dirty=\"0\">"
        xml += "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>"
        xml += "</a:rPr>"
        xml += "<a:t>\(esc(label))</a:t>"
        xml += "</a:r>"
        xml += "</a:p>"

        // Value (large)
        xml += "<a:p>"
        xml += "<a:pPr algn=\"ctr\"/>"
        xml += "<a:r>"
        xml += "<a:rPr lang=\"en-US\" sz=\"\(kpiValueFontSize)\" b=\"1\" dirty=\"0\">"
        xml += "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>"
        xml += "</a:rPr>"
        xml += "<a:t>\(esc(value))</a:t>"
        xml += "</a:r>"
        xml += "</a:p>"

        // Delta
        if let delta = delta, !delta.isEmpty {
            xml += "<a:p>"
            xml += "<a:pPr algn=\"ctr\"/>"
            xml += "<a:r>"
            xml += "<a:rPr lang=\"en-US\" sz=\"\(kpiDeltaFontSize)\" dirty=\"0\">"
            xml += "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>"
            xml += "</a:rPr>"
            xml += "<a:t>\(esc(delta))</a:t>"
            xml += "</a:r>"
            xml += "</a:p>"
        }

        xml += "</p:txBody>"
        xml += "</p:sp>"
        id += 1
        return xml
    }
}

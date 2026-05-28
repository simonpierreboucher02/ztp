@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

/// Shared CoreGraphics drawing logic used by both PNGRenderer and PDFRenderer.
struct CGRenderer {

    /// Execute drawing commands in a CoreGraphics context.
    /// Assumes the coordinate system has already been flipped so that origin is top-left
    /// and y increases downward.
    static func execute(commands: [DrawingCommand], in context: CGContext, width: Double, height: Double) {
        for command in commands {
            switch command {
            case .line(let x1, let y1, let x2, let y2, let color, let lineWidth):
                context.setStrokeColor(cgColor(color))
                context.setLineWidth(lineWidth)
                context.strokeLineSegments(between: [
                    CGPoint(x: x1, y: y1),
                    CGPoint(x: x2, y: y2)
                ])

            case .rect(let x, let y, let w, let h, let fill, let stroke, let strokeWidth):
                let rect = CGRect(x: x, y: y, width: w, height: h)
                if let f = fill {
                    context.setFillColor(cgColor(f))
                    context.fill(rect)
                }
                if let s = stroke, strokeWidth > 0 {
                    context.setStrokeColor(cgColor(s))
                    context.setLineWidth(strokeWidth)
                    context.stroke(rect)
                }

            case .circle(let cx, let cy, let radius, let fill, let stroke, let strokeWidth):
                let rect = CGRect(
                    x: cx - radius, y: cy - radius,
                    width: radius * 2, height: radius * 2
                )
                if let f = fill {
                    context.setFillColor(cgColor(f))
                    context.fillEllipse(in: rect)
                }
                if let s = stroke, strokeWidth > 0 {
                    context.setStrokeColor(cgColor(s))
                    context.setLineWidth(strokeWidth)
                    context.strokeEllipse(in: rect)
                }

            case .text(let x, let y, let content, let fontSize, let color, let anchor, let baseline, let bold, let rotation):
                drawText(
                    in: context, text: content,
                    x: x, y: y,
                    fontSize: fontSize, color: color,
                    anchor: anchor, baseline: baseline,
                    bold: bold, rotation: rotation
                )

            case .polyline(let points, let stroke, let lineWidth, let fill):
                guard points.count >= 2 else { continue }
                let cgPoints = points.map { CGPoint(x: $0.x, y: $0.y) }

                if let f = fill {
                    context.beginPath()
                    context.addLines(between: cgPoints)
                    context.closePath()
                    context.setFillColor(cgColor(f))
                    context.fillPath()
                }

                context.beginPath()
                context.addLines(between: cgPoints)
                context.setStrokeColor(cgColor(stroke))
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.strokePath()

            case .polygon(let points, let fill, let stroke, let strokeWidth):
                guard points.count >= 3 else { continue }
                let cgPoints = points.map { CGPoint(x: $0.x, y: $0.y) }

                context.beginPath()
                context.addLines(between: cgPoints)
                context.closePath()

                context.setFillColor(cgColor(fill))
                if let s = stroke, strokeWidth > 0 {
                    context.setStrokeColor(cgColor(s))
                    context.setLineWidth(strokeWidth)
                    context.drawPath(using: .fillStroke)
                } else {
                    context.fillPath()
                }

            case .path(let d, let fill, let stroke, let strokeWidth):
                // Parse the SVG path `d` attribute into CGPath commands
                if let cgPath = parseSVGPath(d) {
                    context.addPath(cgPath)
                    if let f = fill {
                        context.setFillColor(cgColor(f))
                        if let s = stroke, strokeWidth > 0 {
                            context.setStrokeColor(cgColor(s))
                            context.setLineWidth(strokeWidth)
                            context.drawPath(using: .fillStroke)
                        } else {
                            context.fillPath()
                        }
                    } else if let s = stroke, strokeWidth > 0 {
                        context.setStrokeColor(cgColor(s))
                        context.setLineWidth(strokeWidth)
                        context.strokePath()
                    }
                }

            case .clipRect(let x, let y, let w, let h):
                context.saveGState()
                context.clip(to: CGRect(x: x, y: y, width: w, height: h))

            case .resetClip:
                context.restoreGState()
            }
        }
    }

    // MARK: - Text Drawing

    private static func drawText(
        in context: CGContext,
        text: String,
        x: Double, y: Double,
        fontSize: Double,
        color: ChartColor,
        anchor: TextAnchor,
        baseline: TextBaseline,
        bold: Bool,
        rotation: Double?
    ) {
        let fontName: CFString = bold ? "Helvetica-Bold" as CFString : "Helvetica" as CFString
        let ctFont = CTFontCreateWithName(fontName, fontSize, nil)

        let attributes: [CFString: Any] = [
            kCTFontAttributeName: ctFont,
            kCTForegroundColorFromContextAttributeName: true
        ]

        let attrString = CFAttributedStringCreate(
            kCFAllocatorDefault,
            text as CFString,
            attributes as CFDictionary
        )!
        let line = CTLineCreateWithAttributedString(attrString)

        // Measure text
        var ascent2: CGFloat = 0
        var descent2: CGFloat = 0
        var leading2: CGFloat = 0
        let _ = CTLineGetTypographicBounds(line, &ascent2, &descent2, &leading2)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let textWidth = bounds.width
        let ascent: CGFloat = CTFontGetAscent(ctFont)
        let descent: CGFloat = CTFontGetDescent(ctFont)
        let textHeight = ascent + descent

        // Compute offset based on anchor
        let xOffset: Double
        switch anchor {
        case .start: xOffset = 0
        case .middle: xOffset = -textWidth / 2.0
        case .end: xOffset = -textWidth
        }

        // Compute offset based on baseline
        let yOffset: Double
        switch baseline {
        case .top: yOffset = ascent
        case .middle: yOffset = ascent - textHeight / 2.0
        case .alphabetic: yOffset = 0
        case .bottom: yOffset = -descent
        }

        context.saveGState()
        context.setFillColor(cgColor(color))

        if let rotation = rotation {
            // Rotate around the anchor point
            context.translateBy(x: x, y: y)
            context.rotate(by: rotation * .pi / 180.0)
            context.textPosition = CGPoint(x: xOffset, y: -yOffset)
        } else {
            context.textPosition = CGPoint(x: x + xOffset, y: y - yOffset)
        }

        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Color Conversion

    private static func cgColor(_ color: ChartColor) -> CGColor {
        return CGColor(
            red: color.r,
            green: color.g,
            blue: color.b,
            alpha: color.a
        )
    }

    // MARK: - SVG Path Parser (basic subset)

    /// Parses a subset of SVG path `d` attribute (M, L, Z, C, A commands).
    private static func parseSVGPath(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ","))

        var currentX: Double = 0
        var currentY: Double = 0

        while !scanner.isAtEnd {
            // Try to scan a command letter
            let commandChars = CharacterSet(charactersIn: "MmLlHhVvCcSsQqTtAaZz")
            guard let cmdStr = scanner.scanCharacters(from: commandChars), let cmd = cmdStr.first else {
                // Try skipping a character
                scanner.currentIndex = d.index(after: scanner.currentIndex)
                continue
            }

            switch cmd {
            case "M":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.move(to: CGPoint(x: x, y: y))
                currentX = x; currentY = y
            case "m":
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentX += dx; currentY += dy
                path.move(to: CGPoint(x: currentX, y: currentY))
            case "L":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.addLine(to: CGPoint(x: x, y: y))
                currentX = x; currentY = y
            case "l":
                guard let dx = scanner.scanDouble(), let dy = scanner.scanDouble() else { break }
                currentX += dx; currentY += dy
                path.addLine(to: CGPoint(x: currentX, y: currentY))
            case "H":
                guard let x = scanner.scanDouble() else { break }
                path.addLine(to: CGPoint(x: x, y: currentY))
                currentX = x
            case "h":
                guard let dx = scanner.scanDouble() else { break }
                currentX += dx
                path.addLine(to: CGPoint(x: currentX, y: currentY))
            case "V":
                guard let y = scanner.scanDouble() else { break }
                path.addLine(to: CGPoint(x: currentX, y: y))
                currentY = y
            case "v":
                guard let dy = scanner.scanDouble() else { break }
                currentY += dy
                path.addLine(to: CGPoint(x: currentX, y: currentY))
            case "C":
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x2 = scanner.scanDouble(), let y2 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble() else { break }
                path.addCurve(to: CGPoint(x: x, y: y),
                             control1: CGPoint(x: x1, y: y1),
                             control2: CGPoint(x: x2, y: y2))
                currentX = x; currentY = y
            case "Z", "z":
                path.closeSubpath()
            default:
                // Skip unsupported commands
                break
            }
        }

        return path
    }
}

import Foundation

public struct SVGRenderer: Sendable {

    /// Converts an array of DrawingCommands to a complete SVG document string.
    public static func render(commands: [DrawingCommand], width: Double, height: Double) -> String {
        var lines: [String] = []

        lines.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(width))" height="\(fmt(height))" viewBox="0 0 \(fmt(width)) \(fmt(height))">
        """)

        var clipId = 0
        var currentClipId: Int? = nil

        for command in commands {
            let clipAttr: String
            if let cid = currentClipId {
                clipAttr = " clip-path=\"url(#clip\(cid))\""
            } else {
                clipAttr = ""
            }

            switch command {
            case .line(let x1, let y1, let x2, let y2, let color, let width):
                lines.append("  <line x1=\"\(fmt(x1))\" y1=\"\(fmt(y1))\" x2=\"\(fmt(x2))\" y2=\"\(fmt(y2))\" stroke=\"\(svgColor(color))\" stroke-width=\"\(fmt(width))\" stroke-opacity=\"\(fmt(color.a))\"\(clipAttr)/>")

            case .rect(let x, let y, let w, let h, let fill, let stroke, let strokeWidth):
                var attrs = "x=\"\(fmt(x))\" y=\"\(fmt(y))\" width=\"\(fmt(w))\" height=\"\(fmt(h))\""
                if let f = fill {
                    attrs += " fill=\"\(svgColor(f))\" fill-opacity=\"\(fmt(f.a))\""
                } else {
                    attrs += " fill=\"none\""
                }
                if let s = stroke {
                    attrs += " stroke=\"\(svgColor(s))\" stroke-width=\"\(fmt(strokeWidth))\" stroke-opacity=\"\(fmt(s.a))\""
                }
                lines.append("  <rect \(attrs)\(clipAttr)/>")

            case .circle(let cx, let cy, let radius, let fill, let stroke, let strokeWidth):
                var attrs = "cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(radius))\""
                if let f = fill {
                    attrs += " fill=\"\(svgColor(f))\" fill-opacity=\"\(fmt(f.a))\""
                } else {
                    attrs += " fill=\"none\""
                }
                if let s = stroke {
                    attrs += " stroke=\"\(svgColor(s))\" stroke-width=\"\(fmt(strokeWidth))\" stroke-opacity=\"\(fmt(s.a))\""
                }
                lines.append("  <circle \(attrs)\(clipAttr)/>")

            case .text(let x, let y, let content, let fontSize, let color, let anchor, let baseline, let bold, let rotation):
                let escapedContent = xmlEscape(content)
                let anchorStr = svgTextAnchor(anchor)
                let baselineStr = svgBaseline(baseline)
                let fontWeight = bold ? "bold" : "normal"

                var transformAttr = ""
                if let rotation = rotation {
                    transformAttr = " transform=\"rotate(\(fmt(rotation)),\(fmt(x)),\(fmt(y)))\""
                }

                lines.append("  <text x=\"\(fmt(x))\" y=\"\(fmt(y))\" font-size=\"\(fmt(fontSize))\" fill=\"\(svgColor(color))\" fill-opacity=\"\(fmt(color.a))\" text-anchor=\"\(anchorStr)\" dominant-baseline=\"\(baselineStr)\" font-weight=\"\(fontWeight)\" font-family=\"Helvetica, Arial, sans-serif\"\(transformAttr)\(clipAttr)>\(escapedContent)</text>")

            case .polyline(let points, let stroke, let width, let fill):
                let pointsStr = points.map { "\(fmt($0.x)),\(fmt($0.y))" }.joined(separator: " ")
                var attrs = "points=\"\(pointsStr)\" stroke=\"\(svgColor(stroke))\" stroke-width=\"\(fmt(width))\" stroke-opacity=\"\(fmt(stroke.a))\""
                if let f = fill {
                    attrs += " fill=\"\(svgColor(f))\" fill-opacity=\"\(fmt(f.a))\""
                } else {
                    attrs += " fill=\"none\""
                }
                lines.append("  <polyline \(attrs)\(clipAttr)/>")

            case .polygon(let points, let fill, let stroke, let strokeWidth):
                let pointsStr = points.map { "\(fmt($0.x)),\(fmt($0.y))" }.joined(separator: " ")
                var attrs = "points=\"\(pointsStr)\" fill=\"\(svgColor(fill))\" fill-opacity=\"\(fmt(fill.a))\""
                if let s = stroke {
                    attrs += " stroke=\"\(svgColor(s))\" stroke-width=\"\(fmt(strokeWidth))\" stroke-opacity=\"\(fmt(s.a))\""
                }
                lines.append("  <polygon \(attrs)\(clipAttr)/>")

            case .path(let d, let fill, let stroke, let strokeWidth):
                var attrs = "d=\"\(d)\""
                if let f = fill {
                    attrs += " fill=\"\(svgColor(f))\" fill-opacity=\"\(fmt(f.a))\""
                } else {
                    attrs += " fill=\"none\""
                }
                if let s = stroke {
                    attrs += " stroke=\"\(svgColor(s))\" stroke-width=\"\(fmt(strokeWidth))\" stroke-opacity=\"\(fmt(s.a))\""
                }
                lines.append("  <path \(attrs)\(clipAttr)/>")

            case .clipRect(let x, let y, let w, let h):
                clipId += 1
                currentClipId = clipId
                lines.append("  <defs>")
                lines.append("    <clipPath id=\"clip\(clipId)\">")
                lines.append("      <rect x=\"\(fmt(x))\" y=\"\(fmt(y))\" width=\"\(fmt(w))\" height=\"\(fmt(h))\"/>")
                lines.append("    </clipPath>")
                lines.append("  </defs>")

            case .resetClip:
                currentClipId = nil
            }
        }

        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func svgColor(_ color: ChartColor) -> String {
        return "#\(color.hexString)"
    }

    private static func svgTextAnchor(_ anchor: TextAnchor) -> String {
        switch anchor {
        case .start: return "start"
        case .middle: return "middle"
        case .end: return "end"
        }
    }

    private static func svgBaseline(_ baseline: TextBaseline) -> String {
        switch baseline {
        case .top: return "hanging"
        case .middle: return "central"
        case .bottom: return "text-bottom"
        case .alphabetic: return "alphabetic"
        }
    }

    private static func xmlEscape(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    private static func fmt(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e10 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

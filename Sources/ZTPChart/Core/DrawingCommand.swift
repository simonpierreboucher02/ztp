import Foundation

public enum DrawingCommand: Sendable {
    case line(x1: Double, y1: Double, x2: Double, y2: Double, color: ChartColor, width: Double)
    case rect(x: Double, y: Double, width: Double, height: Double, fill: ChartColor?, stroke: ChartColor?, strokeWidth: Double)
    case circle(cx: Double, cy: Double, radius: Double, fill: ChartColor?, stroke: ChartColor?, strokeWidth: Double)
    case text(x: Double, y: Double, content: String, fontSize: Double, color: ChartColor, anchor: TextAnchor, baseline: TextBaseline, bold: Bool, rotation: Double?)
    case polyline(points: [(x: Double, y: Double)], stroke: ChartColor, width: Double, fill: ChartColor?)
    case polygon(points: [(x: Double, y: Double)], fill: ChartColor, stroke: ChartColor?, strokeWidth: Double)
    case path(d: String, fill: ChartColor?, stroke: ChartColor?, strokeWidth: Double)
    case clipRect(x: Double, y: Double, width: Double, height: Double)
    case resetClip
}

public enum TextAnchor: String, Sendable {
    case start, middle, end
}

public enum TextBaseline: String, Sendable {
    case top, middle, bottom, alphabetic
}

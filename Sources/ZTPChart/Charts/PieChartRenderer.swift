import Foundation

public struct PieChartRenderer: Sendable {

    /// Renders a pie chart using polygon slices (arcs approximated with many segments).
    public static func render(
        data: ChartDataSet,
        labelField: String,
        valueField: String,
        layout: PlotArea,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        guard let labelValues = data.values(for: labelField),
              let numericVals = data.values(for: valueField) else {
            return commands
        }

        // Collect valid slices (row-aligned)
        var slices: [(label: String, value: Double)] = []
        let count = min(labelValues.count, numericVals.count)
        for i in 0..<count {
            guard let label = labelValues[i].asString,
                  let value = numericVals[i].asDouble,
                  value > 0 else { continue }
            slices.append((label: label, value: value))
        }

        guard !slices.isEmpty else { return commands }

        let total = slices.reduce(0.0) { $0 + $1.value }
        guard total > 0 else { return commands }

        let centerX = layout.x + layout.width / 2.0
        let centerY = layout.y + layout.height / 2.0
        let radius = min(layout.width, layout.height) / 2.0 * 0.8
        let labelRadius = radius * 1.15

        // Approximate arc segments: ~100 segments per full circle
        let segmentsPerCircle = 100

        var startAngle: Double = -Double.pi / 2.0 // Start at top

        for (sliceIndex, slice) in slices.enumerated() {
            let sweepAngle = (slice.value / total) * 2.0 * Double.pi
            let endAngle = startAngle + sweepAngle
            let color = theme.color(for: sliceIndex)

            // Build polygon: center, then arc points, then back to center
            var points: [(x: Double, y: Double)] = []
            points.append((x: centerX, y: centerY))

            let numSegments = max(3, Int(Double(segmentsPerCircle) * (sweepAngle / (2.0 * Double.pi))))
            for seg in 0...numSegments {
                let angle = startAngle + sweepAngle * Double(seg) / Double(numSegments)
                let px = centerX + radius * cos(angle)
                let py = centerY + radius * sin(angle)
                points.append((x: px, y: py))
            }

            commands.append(.polygon(
                points: points,
                fill: color,
                stroke: ChartColor(r: 1, g: 1, b: 1, a: 1),
                strokeWidth: 1
            ))

            // Label at midpoint of arc
            let midAngle = startAngle + sweepAngle / 2.0
            let labelX = centerX + labelRadius * cos(midAngle)
            let labelY = centerY + labelRadius * sin(midAngle)

            let anchor: TextAnchor
            if cos(midAngle) > 0.1 {
                anchor = .start
            } else if cos(midAngle) < -0.1 {
                anchor = .end
            } else {
                anchor = .middle
            }

            commands.append(.text(
                x: labelX,
                y: labelY,
                content: slice.label,
                fontSize: 11,
                color: theme.textColor,
                anchor: anchor,
                baseline: .middle,
                bold: false,
                rotation: nil
            ))

            startAngle = endAngle
        }

        return commands
    }
}

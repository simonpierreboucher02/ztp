import Foundation

public struct LegendRenderer: Sendable {

    /// Renders a horizontal legend below the plot area with colored squares and labels.
    public static func render(
        series: [(label: String, color: ChartColor)],
        layout: ChartLayout,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        guard !series.isEmpty, let legendArea = layout.legendArea else { return [] }

        var commands: [DrawingCommand] = []

        let squareSize: Double = 12
        let gap: Double = 8
        let itemSpacing: Double = 24
        let fontSize: Double = 12

        // Estimate total legend width to center it
        let estimatedCharWidth: Double = 7
        var totalWidth: Double = 0
        for (i, s) in series.enumerated() {
            totalWidth += squareSize + gap + (Double(s.label.count) * estimatedCharWidth)
            if i < series.count - 1 {
                totalWidth += itemSpacing
            }
        }

        let legendY = legendArea.y + legendArea.height / 2.0
        var currentX = layout.totalWidth / 2.0 - totalWidth / 2.0

        for s in series {
            // Colored square
            commands.append(.rect(
                x: currentX,
                y: legendY - squareSize / 2.0,
                width: squareSize,
                height: squareSize,
                fill: s.color,
                stroke: nil,
                strokeWidth: 0
            ))
            currentX += squareSize + gap

            // Label
            commands.append(.text(
                x: currentX,
                y: legendY,
                content: s.label,
                fontSize: fontSize,
                color: theme.textColor,
                anchor: .start,
                baseline: .middle,
                bold: false,
                rotation: nil
            ))
            currentX += Double(s.label.count) * estimatedCharWidth + itemSpacing
        }

        return commands
    }
}

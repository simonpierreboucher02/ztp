import Foundation

public struct HeatmapRenderer: Sendable {

    /// Renders a heatmap as a grid of colored rectangles.
    /// Uses all numeric columns. Color gradient from palette[0] (low) to palette[1] (high).
    /// Adds value text in each cell if the grid is not too dense (< 20 cols and < 20 rows).
    public static func render(
        data: ChartDataSet,
        layout: PlotArea,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        // Identify numeric columns (those that have at least one numeric value)
        var numericColumns: [String] = []
        for col in data.columns {
            if let vals = data.values(for: col) {
                let hasNumeric = vals.contains { $0.asDouble != nil }
                if hasNumeric {
                    numericColumns.append(col)
                }
            }
        }

        guard !numericColumns.isEmpty else { return commands }

        let numCols = numericColumns.count
        let numRows = data.rows.count

        guard numRows > 0, numCols > 0 else { return commands }

        // Collect column values (preserving row alignment) and find min/max
        var columnValues: [[ChartValue]] = []
        var globalMin: Double = .infinity
        var globalMax: Double = -.infinity

        for colName in numericColumns {
            let vals = data.values(for: colName) ?? []
            columnValues.append(vals)
            for v in vals {
                if let d = v.asDouble {
                    globalMin = min(globalMin, d)
                    globalMax = max(globalMax, d)
                }
            }
        }

        guard globalMin.isFinite, globalMax.isFinite else { return commands }

        let range = globalMax - globalMin
        let effectiveRange = range > 0 ? range : 1.0

        // Colors
        let lowColor = theme.palette.isEmpty
            ? ChartColor(r: 0.9, g: 0.9, b: 1.0)
            : theme.palette[0]
        let highColor: ChartColor
        if theme.palette.count >= 2 {
            highColor = theme.palette[1]
        } else {
            highColor = ChartColor.defaultAccent
        }

        let cellWidth = layout.width / Double(numCols)
        let cellHeight = layout.height / Double(numRows)
        let showText = numCols < 20 && numRows < 20

        for col in 0..<numCols {
            for row in 0..<numRows {
                let vals = columnValues[col]
                guard row < vals.count else { continue }

                let t: Double
                if let v = vals[row].asDouble {
                    t = (v - globalMin) / effectiveRange
                } else {
                    t = 0
                }

                let cellColor = interpolateColor(from: lowColor, to: highColor, t: t)

                let x = layout.x + Double(col) * cellWidth
                let y = layout.y + Double(row) * cellHeight

                commands.append(.rect(
                    x: x, y: y,
                    width: cellWidth, height: cellHeight,
                    fill: cellColor,
                    stroke: theme.background,
                    strokeWidth: 0.5
                ))

                if showText, let v = vals[row].asDouble {
                    // Choose text color for contrast
                    let textColor = t > 0.5 ? theme.background : theme.textColor
                    let displayText: String
                    if abs(v) >= 1000 || (abs(v) < 0.01 && v != 0) {
                        displayText = String(format: "%.1e", v)
                    } else if v == v.rounded() {
                        displayText = String(format: "%.0f", v)
                    } else {
                        displayText = String(format: "%.2f", v)
                    }

                    commands.append(.text(
                        x: x + cellWidth / 2.0,
                        y: y + cellHeight / 2.0,
                        content: displayText,
                        fontSize: max(8, min(11, cellHeight * 0.4)),
                        color: textColor,
                        anchor: .middle,
                        baseline: .middle,
                        bold: false,
                        rotation: nil
                    ))
                }
            }
        }

        return commands
    }

    // MARK: - Color Interpolation

    private static func interpolateColor(from low: ChartColor, to high: ChartColor, t: Double) -> ChartColor {
        let clamped = max(0, min(1, t))
        return ChartColor(
            r: low.r + (high.r - low.r) * clamped,
            g: low.g + (high.g - low.g) * clamped,
            b: low.b + (high.b - low.b) * clamped,
            a: low.a + (high.a - low.a) * clamped
        )
    }
}

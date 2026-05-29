import Foundation

public struct AxisRenderer: Sendable {

    // MARK: - Y Axis (Linear)

    /// Renders Y-axis line, tick marks, tick labels, and optional axis label.
    public static func renderYAxis(
        scale: any ChartScale,
        layout: PlotArea,
        theme: ChartTheme,
        label: String?,
        tickCount: Int
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let x = layout.x
        let topY = layout.y
        let bottomY = layout.y + layout.height

        // Vertical axis line
        commands.append(.line(
            x1: x, y1: topY,
            x2: x, y2: bottomY,
            color: theme.axisColor, width: 1
        ))

        // Tick marks and labels
        let ticks = scale.ticks(count: tickCount)
        let tickLength: Double = 5

        for tickValue in ticks {
            let yPos = scale.map(tickValue, rangeStart: bottomY, rangeEnd: topY)
            // Tick mark
            commands.append(.line(
                x1: x - tickLength, y1: yPos,
                x2: x, y2: yPos,
                color: theme.axisColor, width: 1
            ))
            // Tick label
            let labelText = scale.label(for: tickValue)
            commands.append(.text(
                x: x - tickLength - 4,
                y: yPos,
                content: labelText,
                fontSize: 11,
                color: theme.textColor,
                anchor: .end,
                baseline: .middle,
                bold: false,
                rotation: nil
            ))
        }

        // Axis label (rotated -90 degrees, centered vertically)
        if let label = label, !label.isEmpty {
            let midY = topY + layout.height / 2.0
            commands.append(.text(
                x: x - 50,
                y: midY,
                content: label,
                fontSize: 13,
                color: theme.textColor,
                anchor: .middle,
                baseline: .middle,
                bold: false,
                rotation: -90
            ))
        }

        return commands
    }

    // MARK: - X Axis (Numeric / Linear)

    /// Renders X-axis with a linear (numeric) scale.
    public static func renderXAxisNumeric(
        scale: any ChartScale,
        layout: PlotArea,
        theme: ChartTheme,
        label: String?,
        tickCount: Int
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let y = layout.y + layout.height

        // Horizontal axis line
        commands.append(.line(
            x1: leftX, y1: y,
            x2: rightX, y2: y,
            color: theme.axisColor, width: 1
        ))

        // Tick marks and labels
        let ticks = scale.ticks(count: tickCount)
        let tickLength: Double = 5

        for tickValue in ticks {
            let xPos = scale.map(tickValue, rangeStart: leftX, rangeEnd: rightX)
            // Tick mark
            commands.append(.line(
                x1: xPos, y1: y,
                x2: xPos, y2: y + tickLength,
                color: theme.axisColor, width: 1
            ))
            // Tick label
            let labelText = scale.label(for: tickValue)
            commands.append(.text(
                x: xPos,
                y: y + tickLength + 12,
                content: labelText,
                fontSize: 11,
                color: theme.textColor,
                anchor: .middle,
                baseline: .top,
                bold: false,
                rotation: nil
            ))
        }

        // Axis label
        if let label = label, !label.isEmpty {
            let midX = leftX + layout.width / 2.0
            commands.append(.text(
                x: midX,
                y: y + 35,
                content: label,
                fontSize: 13,
                color: theme.textColor,
                anchor: .middle,
                baseline: .top,
                bold: false,
                rotation: nil
            ))
        }

        return commands
    }

    // MARK: - X Axis (Categorical)

    /// Renders X-axis with a categorical scale (bar charts, etc.).
    public static func renderXAxisCategorical(
        scale: CategoricalScale,
        layout: PlotArea,
        theme: ChartTheme,
        label: String?
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let y = layout.y + layout.height

        // Horizontal axis line
        commands.append(.line(
            x1: leftX, y1: y,
            x2: rightX, y2: y,
            color: theme.axisColor, width: 1
        ))

        let tickLength: Double = 5

        for (index, category) in scale.categories.enumerated() {
            let centerX = scale.position(for: index, rangeStart: leftX, rangeEnd: rightX)

            // Tick mark
            commands.append(.line(
                x1: centerX, y1: y,
                x2: centerX, y2: y + tickLength,
                color: theme.axisColor, width: 1
            ))
            // Label
            commands.append(.text(
                x: centerX,
                y: y + tickLength + 12,
                content: category,
                fontSize: 11,
                color: theme.textColor,
                anchor: .middle,
                baseline: .top,
                bold: false,
                rotation: nil
            ))
        }

        // Axis label
        if let label = label, !label.isEmpty {
            let midX = leftX + layout.width / 2.0
            commands.append(.text(
                x: midX,
                y: y + 35,
                content: label,
                fontSize: 13,
                color: theme.textColor,
                anchor: .middle,
                baseline: .top,
                bold: false,
                rotation: nil
            ))
        }

        return commands
    }

    // MARK: - Grid Lines

    /// Renders horizontal grid lines at each Y tick value.
    public static func renderGrid(
        yScale: any ChartScale,
        layout: PlotArea,
        theme: ChartTheme,
        tickCount: Int
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let ticks = yScale.ticks(count: tickCount)
        let leftX = layout.x
        let rightX = layout.x + layout.width
        let topY = layout.y
        let bottomY = layout.y + layout.height

        for tickValue in ticks {
            let yPos = yScale.map(tickValue, rangeStart: bottomY, rangeEnd: topY)
            // Skip the bottom line (axis line already drawn)
            if abs(yPos - bottomY) < 0.5 { continue }
            commands.append(.line(
                x1: leftX, y1: yPos,
                x2: rightX, y2: yPos,
                color: theme.gridColor, width: 0.5
            ))
        }

        return commands
    }
}

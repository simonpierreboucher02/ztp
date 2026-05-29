import Foundation

public struct ScatterChartRenderer: Sendable {

    /// Renders scatter plot with circles at each data point.
    public static func render(
        data: ChartDataSet,
        xField: String,
        series: [ChartSeriesConfig],
        xScale: any ChartScale,
        yScale: any ChartScale,
        layout: PlotArea,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        guard let xValues = data.values(for: xField) else { return commands }

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let topY = layout.y
        let bottomY = layout.y + layout.height

        for (seriesIndex, config) in series.enumerated() {
            guard let yValues = data.values(for: config.field) else { continue }
            let color = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)
            let count = min(xValues.count, yValues.count)

            for i in 0..<count {
                guard let xVal = xValues[i].asDouble,
                      let yVal = yValues[i].asDouble else { continue }
                let px = xScale.map(xVal, rangeStart: leftX, rangeEnd: rightX)
                let py = yScale.map(yVal, rangeStart: bottomY, rangeEnd: topY)

                commands.append(.circle(
                    cx: px, cy: py,
                    radius: 4,
                    fill: color,
                    stroke: nil,
                    strokeWidth: 0
                ))
            }
        }

        return commands
    }
}

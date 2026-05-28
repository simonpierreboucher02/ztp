import Foundation

public struct BarChartRenderer: Sendable {

    /// Renders vertical bars, grouping multiple series side-by-side within each category band.
    public static func render(
        data: ChartDataSet,
        xField: String,
        series: [ChartSeriesConfig],
        xScale: CategoricalScale,
        yScale: LinearScale,
        layout: PlotArea,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let topY = layout.y
        let bottomY = layout.y + layout.height

        let bandW = xScale.bandWidth(rangeStart: leftX, rangeEnd: rightX)

        // 20% gap within each band, 80% usable for bars
        let groupPadding = bandW * 0.2
        let usableWidth = bandW - groupPadding
        let seriesCount = max(series.count, 1)
        let barWidth = usableWidth / Double(seriesCount)

        for (catIndex, category) in xScale.categories.enumerated() {
            // position returns the center of the band
            let centerX = xScale.position(for: catIndex, rangeStart: leftX, rangeEnd: rightX)
            let bandStartX = centerX - bandW / 2.0
            let groupStartX = bandStartX + groupPadding / 2.0

            for (seriesIndex, config) in series.enumerated() {
                guard let yValues = data.values(for: config.field) else { continue }
                guard catIndex < yValues.count else { continue }
                guard let yVal = yValues[catIndex].asDouble else { continue }

                let color = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)
                let barX = groupStartX + Double(seriesIndex) * barWidth

                let yPixelVal = yScale.map(yVal, rangeStart: bottomY, rangeEnd: topY)
                let yPixelZero = yScale.map(0, rangeStart: bottomY, rangeEnd: topY)

                let barTop = min(yPixelVal, yPixelZero)
                let barHeight = abs(yPixelVal - yPixelZero)

                commands.append(.rect(
                    x: barX,
                    y: barTop,
                    width: barWidth,
                    height: max(barHeight, 0.5),
                    fill: color,
                    stroke: nil,
                    strokeWidth: 0
                ))
            }
        }

        return commands
    }
}

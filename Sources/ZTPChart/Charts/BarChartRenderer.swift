import Foundation

public struct BarChartRenderer: Sendable {

    /// Renders vertical bars. Series are grouped side-by-side by default, or
    /// stacked when `stacked` is true. Optional value labels are drawn on bars.
    public static func render(
        data: ChartDataSet,
        xField: String,
        series: [ChartSeriesConfig],
        xScale: CategoricalScale,
        yScale: any ChartScale,
        layout: PlotArea,
        theme: ChartTheme,
        stacked: Bool = false,
        dataLabels: Bool = false
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let topY = layout.y
        let bottomY = layout.y + layout.height

        let bandW = xScale.bandWidth(rangeStart: leftX, rangeEnd: rightX)
        let groupPadding = bandW * 0.2
        let usableWidth = bandW - groupPadding
        let seriesCount = max(series.count, 1)
        let barWidth = stacked ? usableWidth : usableWidth / Double(seriesCount)

        let yPixelZero = yScale.map(0, rangeStart: bottomY, rangeEnd: topY)

        func label(_ value: Double, x: Double, y: Double, color: ChartColor) {
            guard dataLabels else { return }
            commands.append(.text(
                x: x, y: y, content: yScale.label(for: value),
                fontSize: 10, color: color, anchor: .middle, baseline: .alphabetic,
                bold: false, rotation: nil
            ))
        }

        for (catIndex, _) in xScale.categories.enumerated() {
            let centerX = xScale.position(for: catIndex, rangeStart: leftX, rangeEnd: rightX)
            let bandStartX = centerX - bandW / 2.0
            let groupStartX = bandStartX + groupPadding / 2.0

            var cumulative = 0.0   // for stacked mode

            for (seriesIndex, config) in series.enumerated() {
                guard let yValues = data.values(for: config.field),
                      catIndex < yValues.count,
                      let yVal = yValues[catIndex].asDouble else { continue }

                let color = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)

                if stacked {
                    let base = cumulative
                    cumulative += yVal
                    let yPixelBase = yScale.map(base, rangeStart: bottomY, rangeEnd: topY)
                    let yPixelTop = yScale.map(cumulative, rangeStart: bottomY, rangeEnd: topY)
                    let barTop = min(yPixelBase, yPixelTop)
                    let barHeight = abs(yPixelBase - yPixelTop)
                    commands.append(.rect(
                        x: groupStartX, y: barTop, width: barWidth,
                        height: max(barHeight, 0.5), fill: color, stroke: nil, strokeWidth: 0
                    ))
                    label(yVal, x: groupStartX + barWidth / 2, y: barTop + barHeight / 2 + 3, color: theme.textColor)
                } else {
                    let barX = groupStartX + Double(seriesIndex) * barWidth
                    let yPixelVal = yScale.map(yVal, rangeStart: bottomY, rangeEnd: topY)
                    let barTop = min(yPixelVal, yPixelZero)
                    let barHeight = abs(yPixelVal - yPixelZero)
                    commands.append(.rect(
                        x: barX, y: barTop, width: barWidth,
                        height: max(barHeight, 0.5), fill: color, stroke: nil, strokeWidth: 0
                    ))
                    label(yVal, x: barX + barWidth / 2, y: barTop - 4, color: theme.textColor)
                }
            }
        }

        return commands
    }
}

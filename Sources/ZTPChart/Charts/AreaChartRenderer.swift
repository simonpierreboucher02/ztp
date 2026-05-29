import Foundation

public struct AreaChartRenderer: Sendable {

    /// Renders area chart: filled polygon from line down to x-axis with semi-transparent fill,
    /// plus a solid polyline on top.
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
            let baseColor = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)
            let fillColor = ChartColor(r: baseColor.r, g: baseColor.g, b: baseColor.b, a: 0.3)

            var linePoints: [(x: Double, y: Double)] = []
            let count = min(xValues.count, yValues.count)

            for i in 0..<count {
                guard let xVal = xValues[i].asDouble,
                      let yVal = yValues[i].asDouble else { continue }
                let px = xScale.map(xVal, rangeStart: leftX, rangeEnd: rightX)
                let py = yScale.map(yVal, rangeStart: bottomY, rangeEnd: topY)
                linePoints.append((x: px, y: py))
            }

            guard linePoints.count >= 2 else { continue }

            // Build polygon: line points + bottom edge (closing back along x-axis)
            var polygonPoints = linePoints
            // Add bottom-right and bottom-left corners to close the area
            polygonPoints.append((x: linePoints.last!.x, y: bottomY))
            polygonPoints.append((x: linePoints.first!.x, y: bottomY))

            // Filled area
            commands.append(.polygon(
                points: polygonPoints,
                fill: fillColor,
                stroke: nil,
                strokeWidth: 0
            ))

            // Outline line
            commands.append(.polyline(
                points: linePoints,
                stroke: baseColor,
                width: 2,
                fill: nil
            ))
        }

        return commands
    }
}

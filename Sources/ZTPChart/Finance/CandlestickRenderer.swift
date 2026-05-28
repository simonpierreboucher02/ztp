import Foundation

public struct CandlestickRenderer: Sendable {

    /// Renders candlestick chart: vertical wicks (high-low) and rectangular bodies (open-close).
    /// Green (#10B981) if close > open, red (#EF4444) if close <= open.
    public static func render(
        data: ChartDataSet,
        dateField: String,
        openField: String,
        highField: String,
        lowField: String,
        closeField: String,
        xScale: CategoricalScale,
        yScale: LinearScale,
        layout: PlotArea,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let greenColor = ChartColor(hex: "10B981")!
        let redColor = ChartColor(hex: "EF4444")!

        let leftX = layout.x
        let rightX = layout.x + layout.width
        let topY = layout.y
        let bottomY = layout.y + layout.height

        guard let dateValues = data.values(for: dateField),
              let openValues = data.values(for: openField),
              let highValues = data.values(for: highField),
              let lowValues = data.values(for: lowField),
              let closeValues = data.values(for: closeField) else {
            return commands
        }

        let bandW = xScale.bandWidth(rangeStart: leftX, rangeEnd: rightX)
        let bodyWidth = bandW * 0.7

        let count = min(dateValues.count,
                       min(openValues.count,
                           min(highValues.count,
                               min(lowValues.count, closeValues.count))))

        for i in 0..<count {
            guard let openVal = openValues[i].asDouble,
                  let highVal = highValues[i].asDouble,
                  let lowVal = lowValues[i].asDouble,
                  let closeVal = closeValues[i].asDouble else { continue }

            // Use the index to get the center position from categorical scale
            guard i < xScale.categories.count else { continue }
            let centerX = xScale.position(for: i, rangeStart: leftX, rangeEnd: rightX)

            let highY = yScale.map(highVal, rangeStart: bottomY, rangeEnd: topY)
            let lowY = yScale.map(lowVal, rangeStart: bottomY, rangeEnd: topY)
            let openY = yScale.map(openVal, rangeStart: bottomY, rangeEnd: topY)
            let closeY = yScale.map(closeVal, rangeStart: bottomY, rangeEnd: topY)

            let isBullish = closeVal > openVal
            let color = isBullish ? greenColor : redColor

            // Wick (high to low)
            commands.append(.line(
                x1: centerX, y1: highY,
                x2: centerX, y2: lowY,
                color: color, width: 1
            ))

            // Body (open to close)
            let bodyTop = min(openY, closeY)
            let bodyHeight = max(abs(openY - closeY), 1) // at least 1px for doji

            commands.append(.rect(
                x: centerX - bodyWidth / 2.0,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight,
                fill: color,
                stroke: color,
                strokeWidth: 1
            ))
        }

        return commands
    }
}

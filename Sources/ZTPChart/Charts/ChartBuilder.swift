import Foundation

public struct ChartBuilder: Sendable {

    /// Main orchestrator: takes a parsed spec and produces drawing commands.
    public static func build(
        type: ChartType,
        data: ChartDataSet,
        spec: ChartSpec,
        theme: ChartTheme,
        width: Double,
        height: Double
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        // 1. Compute layout
        let layout = ChartLayout(
            width: width,
            height: height,
            hasTitle: spec.chart.title != nil,
            hasSubtitle: spec.chart.subtitle != nil,
            hasLegend: spec.legend ?? false,
            hasXLabel: spec.x?.label != nil,
            hasYLabel: spec.y?.label != nil
        )

        // 2. Background rect
        commands.append(.rect(
            x: 0, y: 0,
            width: width, height: height,
            fill: theme.background,
            stroke: nil,
            strokeWidth: 0
        ))

        // 3. Title / subtitle
        commands += TitleRenderer.render(
            title: spec.chart.title,
            subtitle: spec.chart.subtitle,
            layout: layout,
            theme: theme
        )

        // 4. Dispatch to the appropriate chart type
        switch type {
        case .line:
            commands += buildLineChart(data: data, spec: spec, theme: theme, layout: layout)
        case .bar:
            commands += buildBarChart(data: data, spec: spec, theme: theme, layout: layout)
        case .scatter:
            commands += buildScatterChart(data: data, spec: spec, theme: theme, layout: layout)
        case .area:
            commands += buildAreaChart(data: data, spec: spec, theme: theme, layout: layout)
        case .pie:
            commands += buildPieChart(data: data, spec: spec, theme: theme, layout: layout)
        case .heatmap:
            commands += buildHeatmap(data: data, spec: spec, theme: theme, layout: layout)
        case .candlestick:
            commands += buildCandlestick(data: data, spec: spec, theme: theme, layout: layout)
        }

        // 5. Legend
        if spec.legend ?? false {
            let seriesInfo = resolveLegendSeries(spec: spec, type: type, data: data, theme: theme)
            commands += LegendRenderer.render(series: seriesInfo, layout: layout, theme: theme)
        }

        return commands
    }

    // MARK: - Line Chart

    private static func buildLineChart(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []
        let series = spec.series ?? []
        guard let xField = spec.x?.field else { return commands }

        let (xScale, yScale) = computeLinearScales(
            data: data, xField: xField, series: series, spec: spec
        )

        // Grid
        if spec.grid ?? true {
            commands += AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            )
        }
        // Axes
        commands += AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        )
        commands += AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        )

        // Clip to plot area
        commands.append(.clipRect(
            x: layout.plotArea.x, y: layout.plotArea.y,
            width: layout.plotArea.width, height: layout.plotArea.height
        ))
        commands += LineChartRenderer.render(
            data: data, xField: xField, series: series,
            xScale: xScale, yScale: yScale,
            layout: layout.plotArea, theme: theme
        )
        commands.append(.resetClip)

        return commands
    }

    // MARK: - Bar Chart

    private static func buildBarChart(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []
        let series = spec.series ?? []
        guard let xField = spec.x?.field else { return commands }

        let categories = resolveCategories(data: data, field: xField)
        let xScale = CategoricalScale(categories: categories)
        let yScale = computeYScale(data: data, series: series, spec: spec)

        // Grid
        if spec.grid ?? true {
            commands += AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            )
        }
        // Axes
        commands += AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        )
        commands += AxisRenderer.renderXAxisCategorical(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label
        )

        commands += BarChartRenderer.render(
            data: data, xField: xField, series: series,
            xScale: xScale, yScale: yScale,
            layout: layout.plotArea, theme: theme
        )

        return commands
    }

    // MARK: - Scatter Chart

    private static func buildScatterChart(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []
        let series = spec.series ?? []
        guard let xField = spec.x?.field else { return commands }

        let (xScale, yScale) = computeLinearScales(
            data: data, xField: xField, series: series, spec: spec
        )

        // Grid
        if spec.grid ?? true {
            commands += AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            )
        }
        // Axes
        commands += AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        )
        commands += AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        )

        commands.append(.clipRect(
            x: layout.plotArea.x, y: layout.plotArea.y,
            width: layout.plotArea.width, height: layout.plotArea.height
        ))
        commands += ScatterChartRenderer.render(
            data: data, xField: xField, series: series,
            xScale: xScale, yScale: yScale,
            layout: layout.plotArea, theme: theme
        )
        commands.append(.resetClip)

        return commands
    }

    // MARK: - Area Chart

    private static func buildAreaChart(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []
        let series = spec.series ?? []
        guard let xField = spec.x?.field else { return commands }

        let (xScale, yScale) = computeLinearScales(
            data: data, xField: xField, series: series, spec: spec
        )

        // Grid
        if spec.grid ?? true {
            commands += AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            )
        }
        // Axes
        commands += AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        )
        commands += AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        )

        commands.append(.clipRect(
            x: layout.plotArea.x, y: layout.plotArea.y,
            width: layout.plotArea.width, height: layout.plotArea.height
        ))
        commands += AreaChartRenderer.render(
            data: data, xField: xField, series: series,
            xScale: xScale, yScale: yScale,
            layout: layout.plotArea, theme: theme
        )
        commands.append(.resetClip)

        return commands
    }

    // MARK: - Pie Chart

    private static func buildPieChart(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        let labelField = spec.labelField ?? "label"
        let valueField = spec.valueField ?? "value"

        return PieChartRenderer.render(
            data: data, labelField: labelField, valueField: valueField,
            layout: layout.plotArea, theme: theme
        )
    }

    // MARK: - Heatmap

    private static func buildHeatmap(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        return HeatmapRenderer.render(
            data: data, layout: layout.plotArea, theme: theme
        )
    }

    // MARK: - Candlestick

    private static func buildCandlestick(
        data: ChartDataSet, spec: ChartSpec, theme: ChartTheme, layout: ChartLayout
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let ohlc = spec.ohlc ?? OHLCSpec()
        let dateField = ohlc.date
        let openField = ohlc.open
        let highField = ohlc.high
        let lowField = ohlc.low
        let closeField = ohlc.close

        let categories = resolveCategories(data: data, field: dateField)
        let xScale = CategoricalScale(categories: categories)

        // Compute Y scale from high/low values
        var allValues: [Double] = []
        if let highs = data.numericValues(for: highField) {
            allValues += highs
        }
        if let lows = data.numericValues(for: lowField) {
            allValues += lows
        }
        let yScale: LinearScale
        if let yMin = spec.y?.min, let yMax = spec.y?.max {
            yScale = LinearScale(min: yMin, max: yMax)
        } else if !allValues.isEmpty {
            yScale = LinearScale(values: allValues)
        } else {
            yScale = LinearScale(min: 0, max: 1)
        }

        // Grid
        if spec.grid ?? true {
            commands += AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            )
        }
        // Axes
        commands += AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        )
        commands += AxisRenderer.renderXAxisCategorical(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label
        )

        commands += CandlestickRenderer.render(
            data: data,
            dateField: dateField, openField: openField,
            highField: highField, lowField: lowField, closeField: closeField,
            xScale: xScale, yScale: yScale,
            layout: layout.plotArea, theme: theme
        )

        return commands
    }

    // MARK: - Scale Helpers

    /// Compute both X and Y linear scales for line/scatter/area charts.
    private static func computeLinearScales(
        data: ChartDataSet, xField: String, series: [ChartSeriesConfig], spec: ChartSpec
    ) -> (LinearScale, LinearScale) {
        // X scale
        let xScale: LinearScale
        if let xMin = spec.x?.min, let xMax = spec.x?.max {
            xScale = LinearScale(min: xMin, max: xMax)
        } else if let xVals = data.numericValues(for: xField), !xVals.isEmpty {
            xScale = LinearScale(values: xVals)
        } else {
            xScale = LinearScale(min: 0, max: 1)
        }

        let yScale = computeYScale(data: data, series: series, spec: spec)
        return (xScale, yScale)
    }

    /// Compute Y scale from series data.
    private static func computeYScale(
        data: ChartDataSet, series: [ChartSeriesConfig], spec: ChartSpec
    ) -> LinearScale {
        if let yMin = spec.y?.min, let yMax = spec.y?.max {
            return LinearScale(min: yMin, max: yMax)
        }

        var allYValues: [Double] = []
        for config in series {
            if let vals = data.numericValues(for: config.field) {
                allYValues += vals
            }
        }

        if !allYValues.isEmpty {
            // Include 0 in bar charts range
            return LinearScale(values: allYValues)
        }
        return LinearScale(min: 0, max: 1)
    }

    /// Extract categories from a column (string representations of values).
    private static func resolveCategories(data: ChartDataSet, field: String) -> [String] {
        guard let vals = data.values(for: field) else { return [] }
        return vals.compactMap { $0.asString }
    }

    // MARK: - Legend Helpers

    private static func resolveLegendSeries(
        spec: ChartSpec, type: ChartType, data: ChartDataSet, theme: ChartTheme
    ) -> [(label: String, color: ChartColor)] {
        switch type {
        case .pie:
            let labelField = spec.labelField ?? "label"
            guard let labels = data.values(for: labelField) else { return [] }
            return labels.enumerated().compactMap { (i, val) in
                guard let label = val.asString else { return nil }
                return (label: label, color: theme.color(for: i))
            }
        default:
            let series = spec.series ?? []
            return series.enumerated().map { (i, config) in
                let color = config.resolvedColor(theme: theme, seriesIndex: i)
                return (label: config.displayLabel, color: color)
            }
        }
    }
}

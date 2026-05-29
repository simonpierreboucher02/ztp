import Foundation
import CoreGraphics
import CoreText
import ImageIO

// MARK: - Chart Engine

public struct ChartEngine: Sendable {

    // MARK: - Output Format

    public enum OutputFormat: String, Sendable {
        case png, svg, pdf
    }

    // MARK: - Build Result

    public struct BuildResult: Sendable {
        public let data: Data
        public let format: OutputFormat
        public let chartType: ChartType
        public let width: Int
        public let height: Int
        public let pointsRendered: Int

        public init(
            data: Data,
            format: OutputFormat,
            chartType: ChartType,
            width: Int,
            height: Int,
            pointsRendered: Int
        ) {
            self.data = data
            self.format = format
            self.chartType = chartType
            self.width = width
            self.height = height
            self.pointsRendered = pointsRendered
        }
    }

    // MARK: - Build

    /// Build a chart from a spec, returning rendered output data.
    ///
    /// 1. Resolves data (inline values or CSV from spec.data.source relative to basePath).
    /// 2. Resolves the theme (from spec.chart.theme name or default).
    /// 3. Generates drawing commands for the chart type.
    /// 4. Routes to the appropriate renderer (SVG, PNG, PDF).
    /// 5. Returns rendered data with metadata.
    /// Build a linear scale that honours an axis spec's explicit `min`/`max`
    /// (previously these fields were silently ignored). When only one bound is
    /// given the other comes from the auto-fitted domain.
    static func boundedScale(values: [Double], axis: AxisSpec?) -> LinearScale {
        let auto = LinearScale(values: values)
        guard axis?.min != nil || axis?.max != nil else { return auto }
        let lo = axis?.min ?? auto.domainMin
        var hi = axis?.max ?? auto.domainMax
        if hi <= lo { hi = lo + 1 }
        return LinearScale(min: lo, max: hi)
    }

    /// Build the appropriate scale for an axis: a base-10 log scale when the
    /// axis declares `"type": "log"` and all values are positive, otherwise a
    /// linear scale honouring any explicit `min`/`max`.
    static func makeScale(values: [Double], axis: AxisSpec?) -> any ChartScale {
        if axis?.type?.lowercased() == "log" {
            // Log requires a strictly-positive domain; any non-positive value
            // (or min bound) means a log axis is inappropriate → use linear.
            let allPositive = !values.isEmpty && values.allSatisfy { $0 > 0 }
            let minBoundOK = (axis?.min ?? 1) > 0
            if allPositive && minBoundOK {
                if let mn = axis?.min, let mx = axis?.max, mx > mn {
                    return LogScale(min: mn, max: mx)
                }
                return LogScale(values: values)
            }
        }
        return boundedScale(values: values, axis: axis)
    }

    public static func build(
        spec: ChartSpec,
        basePath: String?,
        format: OutputFormat
    ) throws -> BuildResult {
        // 1. Resolve data
        let dataSet = try spec.resolveData(relativeTo: basePath)

        // 2. Resolve theme
        let theme = spec.resolveTheme()

        // 3. Resolve layout
        let layout = spec.resolveLayout()

        // 4. Generate drawing commands
        var commands: [DrawingCommand] = []
        var pointsRendered = 0

        // Background
        commands.append(.rect(
            x: 0, y: 0,
            width: layout.totalWidth, height: layout.totalHeight,
            fill: theme.background,
            stroke: nil,
            strokeWidth: 0
        ))

        // Title
        commands.append(contentsOf: TitleRenderer.render(
            title: spec.chart.title,
            subtitle: spec.chart.subtitle,
            layout: layout,
            theme: theme
        ))

        // Chart-type-specific rendering
        switch spec.chart.type {
        case .line:
            let result = try renderLineChart(
                spec: spec, dataSet: dataSet, layout: layout, theme: theme
            )
            commands.append(contentsOf: result.commands)
            pointsRendered = result.pointCount

        case .bar:
            let result = try renderBarChart(
                spec: spec, dataSet: dataSet, layout: layout, theme: theme
            )
            commands.append(contentsOf: result.commands)
            pointsRendered = result.pointCount

        case .scatter:
            let result = try renderScatterChart(
                spec: spec, dataSet: dataSet, layout: layout, theme: theme
            )
            commands.append(contentsOf: result.commands)
            pointsRendered = result.pointCount

        case .area:
            let result = try renderAreaChart(
                spec: spec, dataSet: dataSet, layout: layout, theme: theme
            )
            commands.append(contentsOf: result.commands)
            pointsRendered = result.pointCount

        case .pie:
            let result = try renderPieChart(
                spec: spec, dataSet: dataSet, layout: layout, theme: theme
            )
            commands.append(contentsOf: result.commands)
            pointsRendered = result.pointCount

        case .heatmap:
            pointsRendered = dataSet.rowCount

        case .candlestick:
            pointsRendered = dataSet.rowCount
        }

        // Legend
        if spec.legend ?? false, let seriesList = spec.series {
            let legendItems: [(label: String, color: ChartColor)] = seriesList.enumerated().map { (i, s) in
                (label: s.displayLabel, color: s.resolvedColor(theme: theme, seriesIndex: i))
            }
            commands.append(contentsOf: LegendRenderer.render(
                series: legendItems,
                layout: layout,
                theme: theme
            ))
        }

        // 5. Render to output format
        let width = Int(spec.chart.width)
        let height = Int(spec.chart.height)
        let outputData: Data

        switch format {
        case .svg:
            outputData = renderSVG(commands: commands, width: width, height: height)

        case .png:
            outputData = try renderPNG(commands: commands, width: width, height: height, theme: theme)

        case .pdf:
            outputData = try renderPDF(commands: commands, width: width, height: height, theme: theme)
        }

        return BuildResult(
            data: outputData,
            format: format,
            chartType: spec.chart.type,
            width: width,
            height: height,
            pointsRendered: pointsRendered
        )
    }

    // MARK: - Line Chart

    private struct RenderResult: Sendable {
        let commands: [DrawingCommand]
        let pointCount: Int
    }

    private static func renderLineChart(
        spec: ChartSpec,
        dataSet: ChartDataSet,
        layout: ChartLayout,
        theme: ChartTheme
    ) throws -> RenderResult {
        guard let seriesList = spec.series, !seriesList.isEmpty else {
            throw ChartSpecError.missingField("series required for line chart")
        }
        guard let xField = spec.x?.field else {
            throw ChartSpecError.missingField("x.field required for line chart")
        }

        var commands: [DrawingCommand] = []
        var pointCount = 0

        // Build scales
        let xValues = dataSet.numericValues(for: xField) ?? []
        var allYValues: [Double] = []
        for s in seriesList {
            if let vals = dataSet.numericValues(for: s.field) {
                allYValues.append(contentsOf: vals)
            }
        }

        let xScale = makeScale(values: xValues, axis: spec.x)
        let yScale = makeScale(values: allYValues, axis: spec.y)

        // Grid
        if spec.grid ?? false {
            commands.append(contentsOf: AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            ))
        }

        // Axes
        commands.append(contentsOf: AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        ))
        commands.append(contentsOf: AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        ))

        // Lines
        commands.append(contentsOf: LineChartRenderer.render(
            data: dataSet,
            xField: xField,
            series: seriesList,
            xScale: xScale,
            yScale: yScale,
            layout: layout.plotArea,
            theme: theme
        ))

        pointCount = xValues.count * seriesList.count

        return RenderResult(commands: commands, pointCount: pointCount)
    }

    // MARK: - Bar Chart

    private static func renderBarChart(
        spec: ChartSpec,
        dataSet: ChartDataSet,
        layout: ChartLayout,
        theme: ChartTheme
    ) throws -> RenderResult {
        guard let seriesList = spec.series, !seriesList.isEmpty else {
            throw ChartSpecError.missingField("series required for bar chart")
        }
        guard let xField = spec.x?.field else {
            throw ChartSpecError.missingField("x.field required for bar chart")
        }

        var commands: [DrawingCommand] = []

        let categories = dataSet.stringValues(for: xField)?.compactMap { $0 } ?? []
        let xScale = CategoricalScale(categories: categories)

        var allYValues: [Double] = []
        for s in seriesList {
            if let vals = dataSet.numericValues(for: s.field) {
                allYValues.append(contentsOf: vals)
            }
        }
        // Stacked bars need the y-domain to cover per-category cumulative sums.
        if spec.stacked ?? false {
            let perSeries = seriesList.map { dataSet.numericValues(for: $0.field) ?? [] }
            let catCount = perSeries.map(\.count).max() ?? 0
            var sums: [Double] = []
            for i in 0..<catCount {
                sums.append(perSeries.reduce(0) { $0 + (i < $1.count ? $1[i] : 0) })
            }
            allYValues = sums + [0]
        }
        let yScale = makeScale(values: allYValues, axis: spec.y)

        // Grid
        if spec.grid ?? false {
            commands.append(contentsOf: AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            ))
        }

        // Axes
        commands.append(contentsOf: AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        ))
        commands.append(contentsOf: AxisRenderer.renderXAxisCategorical(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label
        ))

        // Bars
        commands.append(contentsOf: BarChartRenderer.render(
            data: dataSet,
            xField: xField,
            series: seriesList,
            xScale: xScale,
            yScale: yScale,
            layout: layout.plotArea,
            theme: theme,
            stacked: spec.stacked ?? false,
            dataLabels: spec.dataLabels ?? false
        ))

        let pointCount = categories.count * seriesList.count

        return RenderResult(commands: commands, pointCount: pointCount)
    }

    // MARK: - Scatter Chart

    private static func renderScatterChart(
        spec: ChartSpec,
        dataSet: ChartDataSet,
        layout: ChartLayout,
        theme: ChartTheme
    ) throws -> RenderResult {
        guard let seriesList = spec.series, !seriesList.isEmpty else {
            throw ChartSpecError.missingField("series required for scatter chart")
        }
        guard let xField = spec.x?.field else {
            throw ChartSpecError.missingField("x.field required for scatter chart")
        }

        var commands: [DrawingCommand] = []
        var pointCount = 0

        let xValues = dataSet.numericValues(for: xField) ?? []
        var allYValues: [Double] = []
        for s in seriesList {
            if let vals = dataSet.numericValues(for: s.field) {
                allYValues.append(contentsOf: vals)
            }
        }

        let xScale = makeScale(values: xValues, axis: spec.x)
        let yScale = makeScale(values: allYValues, axis: spec.y)

        // Grid
        if spec.grid ?? false {
            commands.append(contentsOf: AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            ))
        }

        // Axes
        commands.append(contentsOf: AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        ))
        commands.append(contentsOf: AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        ))

        // Scatter points
        let plotArea = layout.plotArea
        let leftX = plotArea.x
        let rightX = plotArea.x + plotArea.width
        let topY = plotArea.y
        let bottomY = plotArea.y + plotArea.height

        for (seriesIndex, config) in seriesList.enumerated() {
            let yValues = dataSet.numericValues(for: config.field) ?? []
            let color = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)
            let count = min(xValues.count, yValues.count)

            for i in 0..<count {
                let px = xScale.map(xValues[i], rangeStart: leftX, rangeEnd: rightX)
                let py = yScale.map(yValues[i], rangeStart: bottomY, rangeEnd: topY)
                commands.append(.circle(
                    cx: px, cy: py,
                    radius: 4,
                    fill: color,
                    stroke: nil,
                    strokeWidth: 0
                ))
                pointCount += 1
            }
        }

        return RenderResult(commands: commands, pointCount: pointCount)
    }

    // MARK: - Area Chart

    private static func renderAreaChart(
        spec: ChartSpec,
        dataSet: ChartDataSet,
        layout: ChartLayout,
        theme: ChartTheme
    ) throws -> RenderResult {
        guard let seriesList = spec.series, !seriesList.isEmpty else {
            throw ChartSpecError.missingField("series required for area chart")
        }
        guard let xField = spec.x?.field else {
            throw ChartSpecError.missingField("x.field required for area chart")
        }

        var commands: [DrawingCommand] = []
        var pointCount = 0

        let xValues = dataSet.numericValues(for: xField) ?? []
        var allYValues: [Double] = []
        for s in seriesList {
            if let vals = dataSet.numericValues(for: s.field) {
                allYValues.append(contentsOf: vals)
            }
        }

        let xScale = makeScale(values: xValues, axis: spec.x)
        let yScale = makeScale(values: allYValues, axis: spec.y)

        // Grid
        if spec.grid ?? false {
            commands.append(contentsOf: AxisRenderer.renderGrid(
                yScale: yScale, layout: layout.plotArea, theme: theme, tickCount: 5
            ))
        }

        // Axes
        commands.append(contentsOf: AxisRenderer.renderYAxis(
            scale: yScale, layout: layout.plotArea, theme: theme,
            label: spec.y?.label, tickCount: 5
        ))
        commands.append(contentsOf: AxisRenderer.renderXAxisNumeric(
            scale: xScale, layout: layout.plotArea, theme: theme,
            label: spec.x?.label, tickCount: 5
        ))

        // Area fills + lines
        let plotArea = layout.plotArea
        let leftX = plotArea.x
        let rightX = plotArea.x + plotArea.width
        let topY = plotArea.y
        let bottomY = plotArea.y + plotArea.height

        for (seriesIndex, config) in seriesList.enumerated() {
            let yValues = dataSet.numericValues(for: config.field) ?? []
            let color = config.resolvedColor(theme: theme, seriesIndex: seriesIndex)
            let count = min(xValues.count, yValues.count)

            var linePoints: [(x: Double, y: Double)] = []
            for i in 0..<count {
                let px = xScale.map(xValues[i], rangeStart: leftX, rangeEnd: rightX)
                let py = yScale.map(yValues[i], rangeStart: bottomY, rangeEnd: topY)
                linePoints.append((x: px, y: py))
            }

            guard !linePoints.isEmpty else { continue }

            // Filled area polygon (from line down to baseline)
            var areaPoints = linePoints
            let baselineY = yScale.map(0, rangeStart: bottomY, rangeEnd: topY)
            areaPoints.append((x: linePoints.last!.x, y: baselineY))
            areaPoints.append((x: linePoints.first!.x, y: baselineY))

            let fillColor = ChartColor(r: color.r, g: color.g, b: color.b, a: 0.3)
            commands.append(.polygon(
                points: areaPoints,
                fill: fillColor,
                stroke: nil,
                strokeWidth: 0
            ))

            // Line on top
            commands.append(.polyline(
                points: linePoints,
                stroke: color,
                width: 2,
                fill: nil
            ))

            pointCount += count
        }

        return RenderResult(commands: commands, pointCount: pointCount)
    }

    // MARK: - Pie Chart

    private static func renderPieChart(
        spec: ChartSpec,
        dataSet: ChartDataSet,
        layout: ChartLayout,
        theme: ChartTheme
    ) throws -> RenderResult {
        guard let labelField = spec.labelField else {
            throw ChartSpecError.missingField("label_field required for pie chart")
        }
        guard let valueField = spec.valueField else {
            throw ChartSpecError.missingField("value_field required for pie chart")
        }

        var commands: [DrawingCommand] = []

        let labels = dataSet.stringValues(for: labelField) ?? []
        let values = dataSet.numericValues(for: valueField) ?? []
        let count = min(labels.count, values.count)

        guard count > 0 else {
            return RenderResult(commands: commands, pointCount: 0)
        }

        let total = values.prefix(count).reduce(0.0, +)
        guard total > 0 else {
            return RenderResult(commands: commands, pointCount: count)
        }

        let plotArea = layout.plotArea
        let cx = plotArea.x + plotArea.width / 2.0
        let cy = plotArea.y + plotArea.height / 2.0
        let radius = min(plotArea.width, plotArea.height) / 2.0 * 0.85

        var startAngle = -Double.pi / 2.0  // Start from top

        for i in 0..<count {
            let sliceValue = values[i]
            let fraction = sliceValue / total
            let sweepAngle = fraction * 2.0 * Double.pi
            let endAngle = startAngle + sweepAngle
            let color = theme.color(for: i)

            // Build SVG arc path
            let x1 = cx + radius * cos(startAngle)
            let y1 = cy + radius * sin(startAngle)
            let x2 = cx + radius * cos(endAngle)
            let y2 = cy + radius * sin(endAngle)
            let largeArc = sweepAngle > Double.pi ? 1 : 0

            let pathD = "M \(cx) \(cy) L \(x1) \(y1) A \(radius) \(radius) 0 \(largeArc) 1 \(x2) \(y2) Z"

            commands.append(.path(
                d: pathD,
                fill: color,
                stroke: theme.background,
                strokeWidth: 2
            ))

            // Label at midpoint of arc
            let midAngle = startAngle + sweepAngle / 2.0
            let labelRadius = radius * 0.65
            let lx = cx + labelRadius * cos(midAngle)
            let ly = cy + labelRadius * sin(midAngle)

            let label = labels[i]
            commands.append(.text(
                x: lx, y: ly,
                content: label,
                fontSize: 12,
                color: theme.background,
                anchor: .middle,
                baseline: .middle,
                bold: false,
                rotation: nil
            ))

            startAngle = endAngle
        }

        return RenderResult(commands: commands, pointCount: count)
    }

    // MARK: - SVG Rendering

    private static func renderSVG(commands: [DrawingCommand], width: Int, height: Int) -> Data {
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">\n
        """

        for command in commands {
            svg += svgElement(for: command)
        }

        svg += "</svg>\n"
        return Data(svg.utf8)
    }

    private static func svgElement(for command: DrawingCommand) -> String {
        switch command {
        case .line(let x1, let y1, let x2, let y2, let color, let width):
            return "  <line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" stroke=\"#\(color.hexString)\" stroke-width=\"\(width)\"/>\n"

        case .rect(let x, let y, let w, let h, let fill, let stroke, let strokeWidth):
            var attrs = "x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\""
            if let fill = fill {
                attrs += " fill=\"\(fill.a < 1.0 ? fill.cssRGBA : "#\(fill.hexString)")\""
            } else {
                attrs += " fill=\"none\""
            }
            if let stroke = stroke {
                attrs += " stroke=\"#\(stroke.hexString)\" stroke-width=\"\(strokeWidth)\""
            }
            return "  <rect \(attrs)/>\n"

        case .circle(let cx, let cy, let radius, let fill, let stroke, let strokeWidth):
            var attrs = "cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(radius)\""
            if let fill = fill {
                attrs += " fill=\"#\(fill.hexString)\""
            } else {
                attrs += " fill=\"none\""
            }
            if let stroke = stroke {
                attrs += " stroke=\"#\(stroke.hexString)\" stroke-width=\"\(strokeWidth)\""
            }
            return "  <circle \(attrs)/>\n"

        case .text(let x, let y, let content, let fontSize, let color, let anchor, let baseline, let bold, let rotation):
            let anchorStr: String
            switch anchor {
            case .start: anchorStr = "start"
            case .middle: anchorStr = "middle"
            case .end: anchorStr = "end"
            }
            let baselineStr: String
            switch baseline {
            case .top: baselineStr = "hanging"
            case .middle: baselineStr = "central"
            case .bottom: baselineStr = "text-after-edge"
            case .alphabetic: baselineStr = "alphabetic"
            }
            var attrs = "x=\"\(x)\" y=\"\(y)\" font-size=\"\(fontSize)\" fill=\"#\(color.hexString)\" text-anchor=\"\(anchorStr)\" dominant-baseline=\"\(baselineStr)\""
            if bold {
                attrs += " font-weight=\"bold\""
            }
            if let rotation = rotation {
                attrs += " transform=\"rotate(\(rotation) \(x) \(y))\""
            }
            let escaped = content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "  <text \(attrs)>\(escaped)</text>\n"

        case .polyline(let points, let stroke, let width, let fill):
            let pointsStr = points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
            var attrs = "points=\"\(pointsStr)\" stroke=\"#\(stroke.hexString)\" stroke-width=\"\(width)\""
            if let fill = fill {
                attrs += " fill=\"\(fill.a < 1.0 ? fill.cssRGBA : "#\(fill.hexString)")\""
            } else {
                attrs += " fill=\"none\""
            }
            return "  <polyline \(attrs)/>\n"

        case .polygon(let points, let fill, let stroke, let strokeWidth):
            let pointsStr = points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
            var attrs = "points=\"\(pointsStr)\" fill=\"\(fill.a < 1.0 ? fill.cssRGBA : "#\(fill.hexString)")\""
            if let stroke = stroke {
                attrs += " stroke=\"#\(stroke.hexString)\" stroke-width=\"\(strokeWidth)\""
            }
            return "  <polygon \(attrs)/>\n"

        case .path(let d, let fill, let stroke, let strokeWidth):
            var attrs = "d=\"\(d)\""
            if let fill = fill {
                attrs += " fill=\"#\(fill.hexString)\""
            } else {
                attrs += " fill=\"none\""
            }
            if let stroke = stroke {
                attrs += " stroke=\"#\(stroke.hexString)\" stroke-width=\"\(strokeWidth)\""
            }
            return "  <path \(attrs)/>\n"

        case .clipRect(let x, let y, let w, let h):
            let id = "clip-\(Int(x))-\(Int(y))-\(Int(w))-\(Int(h))"
            return "  <clipPath id=\"\(id)\"><rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\"/></clipPath>\n  <g clip-path=\"url(#\(id))\">\n"

        case .resetClip:
            return "  </g>\n"
        }
    }

    // MARK: - PNG Rendering

    private static func renderPNG(
        commands: [DrawingCommand],
        width: Int,
        height: Int,
        theme: ChartTheme
    ) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ChartSpecError.invalidSpec("Failed to create bitmap context for PNG rendering")
        }

        // Flip coordinate system (CGContext origin is bottom-left, our commands are top-left)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        renderToCGContext(context: context, commands: commands)

        guard let cgImage = context.makeImage() else {
            throw ChartSpecError.invalidSpec("Failed to create CGImage from context")
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw ChartSpecError.invalidSpec("Failed to create PNG image destination")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ChartSpecError.invalidSpec("Failed to finalize PNG image")
        }

        return mutableData as Data
    }

    // MARK: - PDF Rendering

    private static func renderPDF(
        commands: [DrawingCommand],
        width: Int,
        height: Int,
        theme: ChartTheme
    ) throws -> Data {
        let mutableData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ChartSpecError.invalidSpec("Failed to create PDF context")
        }

        pdfContext.beginPDFPage(nil)

        // Flip coordinate system
        pdfContext.translateBy(x: 0, y: CGFloat(height))
        pdfContext.scaleBy(x: 1, y: -1)

        renderToCGContext(context: pdfContext, commands: commands)

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return mutableData as Data
    }

    // MARK: - Core Graphics Rendering

    private static func renderToCGContext(context: CGContext, commands: [DrawingCommand]) {
        for command in commands {
            switch command {
            case .line(let x1, let y1, let x2, let y2, let color, let width):
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(CGFloat(width))
                context.move(to: CGPoint(x: x1, y: y1))
                context.addLine(to: CGPoint(x: x2, y: y2))
                context.strokePath()

            case .rect(let x, let y, let w, let h, let fill, let stroke, let strokeWidth):
                let rect = CGRect(x: x, y: y, width: w, height: h)
                if let fill = fill {
                    context.setFillColor(fill.cgColor)
                    context.fill(rect)
                }
                if let stroke = stroke {
                    context.setStrokeColor(stroke.cgColor)
                    context.setLineWidth(CGFloat(strokeWidth))
                    context.stroke(rect)
                }

            case .circle(let cx, let cy, let radius, let fill, let stroke, let strokeWidth):
                let rect = CGRect(
                    x: cx - radius, y: cy - radius,
                    width: radius * 2, height: radius * 2
                )
                if let fill = fill {
                    context.setFillColor(fill.cgColor)
                    context.fillEllipse(in: rect)
                }
                if let stroke = stroke {
                    context.setStrokeColor(stroke.cgColor)
                    context.setLineWidth(CGFloat(strokeWidth))
                    context.strokeEllipse(in: rect)
                }

            case .text(let x, let y, let content, let fontSize, let color, _, _, let bold, let rotation):
                context.saveGState()
                if let rotation = rotation {
                    context.translateBy(x: CGFloat(x), y: CGFloat(y))
                    context.rotate(by: CGFloat(rotation) * .pi / 180.0)
                    context.translateBy(x: CGFloat(-x), y: CGFloat(-y))
                }

                let fontName = bold ? "Helvetica-Bold" : "Helvetica"
                let ctFont = CTFontCreateWithName(fontName as CFString, CGFloat(fontSize), nil)
                let attributes: [CFString: Any] = [
                    kCTFontAttributeName: ctFont,
                    kCTForegroundColorAttributeName: color.cgColor
                ]
                let attrString = CFAttributedStringCreate(
                    kCFAllocatorDefault,
                    content as CFString,
                    attributes as CFDictionary
                )!
                let line = CTLineCreateWithAttributedString(attrString as CFAttributedString)
                context.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, context)
                context.restoreGState()

            case .polyline(let points, let stroke, let width, let fill):
                guard !points.isEmpty else { continue }
                context.beginPath()
                context.move(to: CGPoint(x: points[0].x, y: points[0].y))
                for i in 1..<points.count {
                    context.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
                }
                if let fill = fill {
                    context.setFillColor(fill.cgColor)
                    context.fillPath()
                    // Re-draw path for stroke
                    context.beginPath()
                    context.move(to: CGPoint(x: points[0].x, y: points[0].y))
                    for i in 1..<points.count {
                        context.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
                    }
                }
                context.setStrokeColor(stroke.cgColor)
                context.setLineWidth(CGFloat(width))
                context.strokePath()

            case .polygon(let points, let fill, let stroke, let strokeWidth):
                guard !points.isEmpty else { continue }
                context.beginPath()
                context.move(to: CGPoint(x: points[0].x, y: points[0].y))
                for i in 1..<points.count {
                    context.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
                }
                context.closePath()
                context.setFillColor(fill.cgColor)
                context.fillPath()
                if let stroke = stroke {
                    context.beginPath()
                    context.move(to: CGPoint(x: points[0].x, y: points[0].y))
                    for i in 1..<points.count {
                        context.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
                    }
                    context.closePath()
                    context.setStrokeColor(stroke.cgColor)
                    context.setLineWidth(CGFloat(strokeWidth))
                    context.strokePath()
                }

            case .path(let d, let fill, let stroke, let strokeWidth):
                guard let cgPath = parseSVGPath(d) else { continue }
                if let fill = fill {
                    context.addPath(cgPath)
                    context.setFillColor(fill.cgColor)
                    context.fillPath()
                }
                if let stroke = stroke {
                    context.addPath(cgPath)
                    context.setStrokeColor(stroke.cgColor)
                    context.setLineWidth(CGFloat(strokeWidth))
                    context.strokePath()
                }

            case .clipRect(let x, let y, let w, let h):
                context.saveGState()
                context.clip(to: CGRect(x: x, y: y, width: w, height: h))

            case .resetClip:
                context.restoreGState()
            }
        }
    }

    // MARK: - SVG Path Parser (minimal subset for pie arcs)

    private static func parseSVGPath(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        let tokens = tokenizePath(d)
        var i = 0

        func nextDouble() -> Double? {
            guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
            i += 1
            return v
        }

        while i < tokens.count {
            let token = tokens[i]
            i += 1

            switch token {
            case "M":
                guard let x = nextDouble(), let y = nextDouble() else { return nil }
                path.move(to: CGPoint(x: x, y: y))

            case "L":
                guard let x = nextDouble(), let y = nextDouble() else { return nil }
                path.addLine(to: CGPoint(x: x, y: y))

            case "A":
                // rx ry x-rotation large-arc-flag sweep-flag x y
                guard let rx = nextDouble(),
                      let _ = nextDouble(),   // ry (same as rx for circles)
                      let _ = nextDouble(),   // x-rotation
                      let _ = nextDouble(),      // large-arc-flag
                      let sweep = nextDouble(),
                      let ex = nextDouble(),
                      let ey = nextDouble() else { return nil }

                // Approximate arc with CGPath addArc
                // For pie chart arcs, we can use the center-based approach
                let currentPoint = path.currentPoint
                let cx = (currentPoint.x + CGFloat(ex)) / 2.0
                let cy = (currentPoint.y + CGFloat(ey)) / 2.0
                let startAngle = atan2(currentPoint.y - cy, currentPoint.x - cx)
                let endAngle = atan2(CGFloat(ey) - cy, CGFloat(ex) - cx)
                let clockwise = sweep == 0

                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: CGFloat(rx),
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: clockwise
                )

            case "Z", "z":
                path.closeSubpath()

            default:
                // Skip numeric tokens that follow previous commands
                let _ = Double(token)
            }
        }

        return path
    }

    private static func tokenizePath(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for ch in d {
            if ch.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(ch))
            } else if ch == " " || ch == "," {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if ch == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                tokens.append(current)
                current = String(ch)
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

// MARK: - ChartColor CGColor Extension

extension ChartColor {
    var cgColor: CGColor {
        return CGColor(
            red: CGFloat(r),
            green: CGFloat(g),
            blue: CGFloat(b),
            alpha: CGFloat(a)
        )
    }
}

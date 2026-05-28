import Foundation

public struct PlotArea: Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TitleArea: Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct LegendArea: Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ChartLayout: Sendable {
    public let totalWidth: Double
    public let totalHeight: Double
    public let plotArea: PlotArea
    public let titleArea: TitleArea?
    public let legendArea: LegendArea?

    /// Compute a layout with standard margins.
    ///
    /// Margins:
    /// - top: 60 if title, +25 if subtitle
    /// - bottom: 60 (x-axis + label)
    /// - left: 80 (y-axis + label)
    /// - right: 40
    /// - legend adds 30 to bottom
    public init(
        width: Double,
        height: Double,
        hasTitle: Bool,
        hasSubtitle: Bool,
        hasLegend: Bool,
        hasXLabel: Bool,
        hasYLabel: Bool
    ) {
        self.totalWidth = width
        self.totalHeight = height

        var topMargin: Double = 20
        var bottomMargin: Double = 40
        var leftMargin: Double = 60
        let rightMargin: Double = 40

        // Title area
        if hasTitle {
            topMargin = 60
            if hasSubtitle {
                topMargin = 85
            }
        }

        // Axis labels
        if hasXLabel {
            bottomMargin = 60
        }
        if hasYLabel {
            leftMargin = 80
        }

        // Legend
        if hasLegend {
            bottomMargin += 30
        }

        // Title area computation
        if hasTitle {
            let titleHeight = hasSubtitle ? topMargin - 10 : topMargin - 10
            self.titleArea = TitleArea(
                x: leftMargin,
                y: 0,
                width: width - leftMargin - rightMargin,
                height: titleHeight
            )
        } else {
            self.titleArea = nil
        }

        // Plot area
        let plotX = leftMargin
        let plotY = topMargin
        let plotWidth = max(0, width - leftMargin - rightMargin)
        let plotHeight = max(0, height - topMargin - bottomMargin)
        self.plotArea = PlotArea(x: plotX, y: plotY, width: plotWidth, height: plotHeight)

        // Legend area (below plot)
        if hasLegend {
            self.legendArea = LegendArea(
                x: leftMargin,
                y: plotY + plotHeight + (hasXLabel ? 45 : 25),
                width: plotWidth,
                height: 25
            )
        } else {
            self.legendArea = nil
        }
    }
}

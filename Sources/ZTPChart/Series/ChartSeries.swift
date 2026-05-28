import Foundation

public struct ChartSeriesConfig: Codable, Sendable, Equatable {
    public let field: String
    public let label: String?
    public let color: String?

    public init(field: String, label: String? = nil, color: String? = nil) {
        self.field = field
        self.label = label
        self.color = color
    }

    /// Resolve the color string (hex) to a ChartColor, falling back to a theme color.
    public func resolvedColor(theme: ChartTheme, seriesIndex: Int) -> ChartColor {
        if let hex = color, let c = ChartColor(hex: hex) {
            return c
        }
        return theme.color(for: seriesIndex)
    }

    /// The display label, defaulting to the field name.
    public var displayLabel: String {
        return label ?? field
    }
}

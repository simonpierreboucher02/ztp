import Foundation

public enum ChartType: String, Codable, Sendable, Equatable {
    case line, bar, scatter, area, pie, heatmap, candlestick
}

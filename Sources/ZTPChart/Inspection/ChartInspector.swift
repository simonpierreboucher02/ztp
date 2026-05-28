import Foundation

// MARK: - Chart Inspector

public struct ChartInspector: Sendable {

    // MARK: - Info Types

    public struct ChartInfo: Codable, Sendable {
        public let chartType: String
        public let width: Int
        public let height: Int
        public let seriesCount: Int
        public let dataPoints: Int
        public let hasTitle: Bool
        public let hasLegend: Bool
        public let hasGrid: Bool
        public let theme: String?

        public init(
            chartType: String,
            width: Int,
            height: Int,
            seriesCount: Int,
            dataPoints: Int,
            hasTitle: Bool,
            hasLegend: Bool,
            hasGrid: Bool,
            theme: String?
        ) {
            self.chartType = chartType
            self.width = width
            self.height = height
            self.seriesCount = seriesCount
            self.dataPoints = dataPoints
            self.hasTitle = hasTitle
            self.hasLegend = hasLegend
            self.hasGrid = hasGrid
            self.theme = theme
        }
    }

    public struct DataSummary: Codable, Sendable {
        public let columns: [String]
        public let rowCount: Int
        public let columnSummaries: [ColumnSummary]

        public init(columns: [String], rowCount: Int, columnSummaries: [ColumnSummary]) {
            self.columns = columns
            self.rowCount = rowCount
            self.columnSummaries = columnSummaries
        }
    }

    public struct ColumnSummary: Codable, Sendable {
        public let name: String
        public let type: String   // "numeric" or "string"
        public let count: Int
        public let missing: Int
        public let min: Double?
        public let max: Double?
        public let mean: Double?

        public init(
            name: String,
            type: String,
            count: Int,
            missing: Int,
            min: Double?,
            max: Double?,
            mean: Double?
        ) {
            self.name = name
            self.type = type
            self.count = count
            self.missing = missing
            self.min = min
            self.max = max
            self.mean = mean
        }
    }

    // MARK: - Inspect from ChartSpec

    public static func inspect(spec: ChartSpec) -> ChartInfo {
        let seriesCount: Int
        switch spec.chart.type {
        case .pie:
            // Pie charts have a single implicit series
            seriesCount = 1
        case .candlestick:
            // Candlestick has OHLC as a single series
            seriesCount = 1
        default:
            seriesCount = spec.series?.count ?? 0
        }

        let dataPoints: Int
        if let rows = spec.data.values {
            dataPoints = rows.count
        } else {
            // Data is external; report 0 since we cannot load it without I/O
            dataPoints = 0
        }

        return ChartInfo(
            chartType: spec.chart.type.rawValue,
            width: Int(spec.chart.width),
            height: Int(spec.chart.height),
            seriesCount: seriesCount,
            dataPoints: dataPoints,
            hasTitle: spec.chart.title != nil && !(spec.chart.title!.isEmpty),
            hasLegend: spec.legend ?? false,
            hasGrid: spec.grid ?? false,
            theme: spec.chart.theme
        )
    }

    // MARK: - Inspect from JSON

    public static func inspect(jsonData: Data) throws -> ChartInfo {
        let spec = try ChartSpec.from(json: jsonData)
        return inspect(spec: spec)
    }

    // MARK: - Data Summary from ChartSpec

    public static func dataSummary(spec: ChartSpec, basePath: String? = nil) throws -> DataSummary {
        let dataSet = try spec.resolveData(relativeTo: basePath)
        return summarize(dataSet: dataSet)
    }

    // MARK: - Data Summary from JSON

    public static func dataSummary(jsonData: Data, basePath: String? = nil) throws -> DataSummary {
        let spec = try ChartSpec.from(json: jsonData)
        return try dataSummary(spec: spec, basePath: basePath)
    }

    // MARK: - Internal

    private static func summarize(dataSet: ChartDataSet) -> DataSummary {
        var columnSummaries: [ColumnSummary] = []

        for column in dataSet.columns {
            guard let values = dataSet.values(for: column) else {
                columnSummaries.append(ColumnSummary(
                    name: column,
                    type: "string",
                    count: 0,
                    missing: dataSet.rowCount,
                    min: nil,
                    max: nil,
                    mean: nil
                ))
                continue
            }

            // Count missing entries
            let missingCount = values.filter { value in
                if case .missing = value { return true }
                return false
            }.count

            let presentCount = values.count - missingCount

            // Determine type: count how many non-missing values parse as numeric
            var numericCount = 0
            var numericValues: [Double] = []

            for value in values {
                switch value {
                case .number(let d):
                    numericCount += 1
                    numericValues.append(d)
                case .string(let s):
                    if let d = Double(s) {
                        numericCount += 1
                        numericValues.append(d)
                    }
                case .missing:
                    break
                }
            }

            // Consider "numeric" if more than half of present values are numeric
            let isNumeric = presentCount > 0 && numericCount > presentCount / 2

            if isNumeric && !numericValues.isEmpty {
                let minVal = numericValues.min()!
                let maxVal = numericValues.max()!
                let sum = numericValues.reduce(0.0, +)
                let meanVal = sum / Double(numericValues.count)

                columnSummaries.append(ColumnSummary(
                    name: column,
                    type: "numeric",
                    count: presentCount,
                    missing: missingCount,
                    min: minVal,
                    max: maxVal,
                    mean: meanVal
                ))
            } else {
                columnSummaries.append(ColumnSummary(
                    name: column,
                    type: "string",
                    count: presentCount,
                    missing: missingCount,
                    min: nil,
                    max: nil,
                    mean: nil
                ))
            }
        }

        return DataSummary(
            columns: dataSet.columns,
            rowCount: dataSet.rowCount,
            columnSummaries: columnSummaries
        )
    }
}

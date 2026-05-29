import Foundation

// MARK: - Errors

public enum ChartSpecError: Error, Sendable {
    case invalidVersion(String)
    case missingChartType
    case missingData
    case missingField(String)
    case unsupportedChartType(String)
    case dataLoadError(String)
    case invalidSpec(String)
}

// MARK: - Sub-specs

public struct ChartMeta: Codable, Sendable, Equatable {
    public let type: ChartType
    public let title: String?
    public let subtitle: String?
    public let width: Double
    public let height: Double
    public let theme: String?

    public init(
        type: ChartType,
        title: String? = nil,
        subtitle: String? = nil,
        width: Double = 1400,
        height: Double = 800,
        theme: String? = nil
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.height = height
        self.theme = theme
    }
}

public struct DataSpec: Codable, Sendable, Equatable {
    public let values: [DataRow]?
    public let source: String?

    public init(values: [DataRow]? = nil, source: String? = nil) {
        self.values = values
        self.source = source
    }
}

public struct AxisSpec: Codable, Sendable, Equatable {
    public let field: String?
    public let type: String?
    public let label: String?
    public let min: Double?
    public let max: Double?

    public init(
        field: String? = nil,
        type: String? = nil,
        label: String? = nil,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.field = field
        self.type = type
        self.label = label
        self.min = min
        self.max = max
    }
}

public struct OHLCSpec: Codable, Sendable, Equatable {
    public let date: String
    public let open: String
    public let high: String
    public let low: String
    public let close: String

    public init(
        date: String = "date",
        open: String = "open",
        high: String = "high",
        low: String = "low",
        close: String = "close"
    ) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }
}

// MARK: - Main Spec

public struct ChartSpec: Codable, Sendable, Equatable {
    public let version: String
    public let chart: ChartMeta
    public let data: DataSpec
    public let x: AxisSpec?
    public let y: AxisSpec?
    public let series: [ChartSeriesConfig]?
    public let legend: Bool?
    public let grid: Bool?
    /// Stack series (bar/area) instead of grouping side-by-side.
    public let stacked: Bool?
    /// Draw value labels on data points/bars.
    public let dataLabels: Bool?

    // Pie-specific
    public let labelField: String?
    public let valueField: String?

    // Candlestick-specific
    public let ohlc: OHLCSpec?

    enum CodingKeys: String, CodingKey {
        case version, chart, data, x, y, series, legend, grid, stacked
        case dataLabels = "data_labels"
        case labelField = "label_field"
        case valueField = "value_field"
        case ohlc
    }

    public init(
        version: String = "ztp-chart/0.1",
        chart: ChartMeta,
        data: DataSpec,
        x: AxisSpec? = nil,
        y: AxisSpec? = nil,
        series: [ChartSeriesConfig]? = nil,
        legend: Bool? = nil,
        grid: Bool? = nil,
        stacked: Bool? = nil,
        dataLabels: Bool? = nil,
        labelField: String? = nil,
        valueField: String? = nil,
        ohlc: OHLCSpec? = nil
    ) {
        self.version = version
        self.chart = chart
        self.data = data
        self.x = x
        self.y = y
        self.series = series
        self.legend = legend
        self.grid = grid
        self.stacked = stacked
        self.dataLabels = dataLabels
        self.labelField = labelField
        self.valueField = valueField
        self.ohlc = ohlc
    }

    // MARK: - Decoding from JSON

    /// Decode a ChartSpec from JSON data.
    public static func from(json data: Data) throws -> ChartSpec {
        let decoder = JSONDecoder()
        return try decoder.decode(ChartSpec.self, from: data)
    }

    /// Decode a ChartSpec from a JSON string.
    public static func from(jsonString: String) throws -> ChartSpec {
        guard let data = jsonString.data(using: .utf8) else {
            throw ChartSpecError.invalidSpec("Unable to encode string as UTF-8")
        }
        return try from(json: data)
    }

    /// Decode a ChartSpec from a JSON file.
    public static func from(file path: String) throws -> ChartSpec {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try from(json: data)
    }

    // MARK: - Data Resolution

    /// Resolve the data spec to a ChartDataSet.
    /// If inline values are present, use them. Otherwise, load from CSV source path.
    public func resolveData(relativeTo basePath: String? = nil) throws -> ChartDataSet {
        if let rows = data.values, !rows.isEmpty {
            return InlineDataLoader.load(from: rows)
        }
        if let source = data.source {
            let resolvedPath: String
            if source.hasPrefix("/") {
                resolvedPath = source
            } else if let base = basePath {
                let baseURL = URL(fileURLWithPath: base).deletingLastPathComponent()
                resolvedPath = baseURL.appendingPathComponent(source).path
            } else {
                resolvedPath = source
            }
            return try CSVLoader.load(from: resolvedPath)
        }
        throw ChartSpecError.missingData
    }

    // MARK: - Theme Resolution

    /// Resolve the theme, defaulting to zyquo-light.
    public func resolveTheme() -> ChartTheme {
        if let name = chart.theme, let theme = ChartTheme.named(name) {
            return theme
        }
        return .zyquoLight
    }

    // MARK: - Layout Resolution

    /// Build a ChartLayout from the spec's dimensions and content flags.
    public func resolveLayout() -> ChartLayout {
        return ChartLayout(
            width: chart.width,
            height: chart.height,
            hasTitle: chart.title != nil,
            hasSubtitle: chart.subtitle != nil,
            hasLegend: legend ?? false,
            hasXLabel: x?.label != nil,
            hasYLabel: y?.label != nil
        )
    }

    // MARK: - Validation

    /// Validate the spec for common errors.
    public func validate() throws {
        guard version.hasPrefix("ztp-chart/") else {
            throw ChartSpecError.invalidVersion(version)
        }

        // Check that data is available
        if data.values == nil && data.source == nil {
            throw ChartSpecError.missingData
        }

        // Chart-type-specific validation
        switch chart.type {
        case .pie:
            if labelField == nil {
                throw ChartSpecError.missingField("label_field is required for pie charts")
            }
            if valueField == nil {
                throw ChartSpecError.missingField("value_field is required for pie charts")
            }
        case .candlestick:
            if ohlc == nil {
                throw ChartSpecError.missingField("ohlc is required for candlestick charts")
            }
        case .line, .bar, .scatter, .area:
            if x?.field == nil && (series == nil || series!.isEmpty) {
                // Acceptable if data has obvious structure, but warn-worthy
            }
        case .heatmap:
            break
        }
    }
}

// MARK: - DataSpec Equatable conformance for DataRow

extension DataRow: Equatable {
    public static func == (lhs: DataRow, rhs: DataRow) -> Bool {
        return lhs.values == rhs.values
    }
}

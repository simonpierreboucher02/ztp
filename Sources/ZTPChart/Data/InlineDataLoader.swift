import Foundation

public enum DataValue: Codable, Sendable, Equatable {
    case number(Double)
    case string(String)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .number(Double(intValue))
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let v):
            try container.encode(v)
        case .string(let s):
            try container.encode(s)
        case .null:
            try container.encodeNil()
        }
    }

    /// Convert to ChartValue for use in ChartDataSet.
    public var chartValue: ChartValue {
        switch self {
        case .number(let v): return .number(v)
        case .string(let s): return .string(s)
        case .null: return .missing
        }
    }
}

public struct DataRow: Codable, Sendable {
    public let values: [String: DataValue]

    public init(values: [String: DataValue]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var dict: [String: DataValue] = [:]
        for key in container.allKeys {
            let value = try container.decode(DataValue.self, forKey: key)
            dict[key.stringValue] = value
        }
        self.values = dict
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            let codingKey = DynamicCodingKey(stringValue: key)!
            try container.encode(value, forKey: codingKey)
        }
    }
}

// MARK: - Dynamic Coding Key

public struct DynamicCodingKey: CodingKey, Sendable {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Inline Data Loader

public struct InlineDataLoader: Sendable {

    /// Convert an array of DataRow into a ChartDataSet.
    /// Column order is determined by the first row; subsequent rows may add new columns.
    public static func load(from rows: [DataRow]) -> ChartDataSet {
        guard !rows.isEmpty else {
            return ChartDataSet(columns: [], rows: [])
        }

        // Gather all unique column names, preserving insertion order from first row
        var columnSet: Set<String> = []
        var columns: [String] = []
        for row in rows {
            for key in row.values.keys.sorted() {
                if !columnSet.contains(key) {
                    columnSet.insert(key)
                    columns.append(key)
                }
            }
        }

        // Build rows
        let chartRows: [[ChartValue]] = rows.map { row in
            columns.map { col in
                guard let dv = row.values[col] else { return .missing }
                return dv.chartValue
            }
        }

        return ChartDataSet(columns: columns, rows: chartRows)
    }
}

import Foundation

public enum ChartValue: Sendable, Equatable {
    case number(Double)
    case string(String)
    case missing

    public var asDouble: Double? {
        switch self {
        case .number(let v): return v
        case .string(let s): return Double(s)
        case .missing: return nil
        }
    }

    public var asString: String? {
        switch self {
        case .number(let v):
            if v == v.rounded() && abs(v) < 1e15 {
                return String(Int(v))
            }
            return String(v)
        case .string(let s): return s
        case .missing: return nil
        }
    }
}

public struct ChartDataSet: Sendable {
    public let columns: [String]
    public let rows: [[ChartValue]]

    public init(columns: [String], rows: [[ChartValue]]) {
        self.columns = columns
        self.rows = rows
    }

    public var rowCount: Int {
        return rows.count
    }

    /// Returns all values for a given column name.
    public func values(for column: String) -> [ChartValue]? {
        guard let index = columns.firstIndex(of: column) else { return nil }
        return rows.map { row in
            index < row.count ? row[index] : .missing
        }
    }

    /// Returns numeric values for a given column, skipping missing/non-numeric entries.
    public func numericValues(for column: String) -> [Double]? {
        guard let vals = values(for: column) else { return nil }
        let doubles = vals.compactMap { $0.asDouble }
        return doubles.isEmpty ? nil : doubles
    }

    /// Returns string values for a given column, skipping missing entries.
    public func stringValues(for column: String) -> [String]? {
        guard let vals = values(for: column) else { return nil }
        let strings = vals.compactMap { $0.asString }
        return strings.isEmpty ? nil : strings
    }
}

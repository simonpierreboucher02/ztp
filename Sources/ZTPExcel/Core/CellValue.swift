// CellValue.swift
// ZTPExcel – Enum representing the value held by a cell.

import Foundation

/// The value stored in a worksheet cell.
public enum CellValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case date(Date)
    case formula(String)
    case blank
}

// MARK: - Codable

extension CellValue: Codable {

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum ValueType: String, Codable {
        case string, number, integer, boolean, date, formula, blank
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let v):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .number(let v):
            try container.encode(ValueType.number, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .integer(let v):
            try container.encode(ValueType.integer, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .boolean(let v):
            try container.encode(ValueType.boolean, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .date(let v):
            try container.encode(ValueType.date, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .formula(let v):
            try container.encode(ValueType.formula, forKey: .type)
            try container.encode(v, forKey: .payload)
        case .blank:
            try container.encode(ValueType.blank, forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)
        switch type {
        case .string:
            self = .string(try container.decode(String.self, forKey: .payload))
        case .number:
            self = .number(try container.decode(Double.self, forKey: .payload))
        case .integer:
            self = .integer(try container.decode(Int.self, forKey: .payload))
        case .boolean:
            self = .boolean(try container.decode(Bool.self, forKey: .payload))
        case .date:
            self = .date(try container.decode(Date.self, forKey: .payload))
        case .formula:
            self = .formula(try container.decode(String.self, forKey: .payload))
        case .blank:
            self = .blank
        }
    }
}

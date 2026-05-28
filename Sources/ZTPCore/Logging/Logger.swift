import Foundation

public enum LogLevel: String, Codable, Sendable {
    case trace
    case debug
    case info
    case warning
    case error
}

public struct LogEntry: Codable, Sendable {
    public let level: LogLevel
    public let event: String
    public let message: String?
    public let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case level, event, message, timestamp
    }
}

public actor ZTPLogger {
    public static let shared = ZTPLogger()

    public var minimumLevel: LogLevel = .info
    public var jsonOutput: Bool = false

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    public func log(_ level: LogLevel, event: String, message: String? = nil) {
        guard shouldLog(level) else { return }

        let entry = LogEntry(level: level, event: event, message: message, timestamp: Date())

        if jsonOutput {
            if let data = try? encoder.encode(entry),
               let json = String(data: data, encoding: .utf8) {
                FileHandle.standardError.write(Data((json + "\n").utf8))
            }
        } else {
            let msg = message.map { ": \($0)" } ?? ""
            FileHandle.standardError.write(Data("[\(level.rawValue)] \(event)\(msg)\n".utf8))
        }
    }

    private func shouldLog(_ level: LogLevel) -> Bool {
        let order: [LogLevel] = [.trace, .debug, .info, .warning, .error]
        guard let target = order.firstIndex(of: minimumLevel),
              let current = order.firstIndex(of: level) else { return false }
        return current >= target
    }
}

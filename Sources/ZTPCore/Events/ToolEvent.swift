import Foundation
import ZTPProtocols

public struct ToolEvent: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case start
        case progress
        case warning
        case metric
        case stdout
        case stderr
        case done
        case error
    }

    public let event: Kind
    public let tool: String
    public let traceID: String
    public let timestamp: Date
    public let percent: Int?
    public let message: String?

    public init(
        event: Kind,
        tool: String,
        traceID: String,
        timestamp: Date = Date(),
        percent: Int? = nil,
        message: String? = nil
    ) {
        self.event = event
        self.tool = tool
        self.traceID = traceID
        self.timestamp = timestamp
        self.percent = percent
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case event
        case tool
        case traceID = "trace_id"
        case timestamp
        case percent
        case message
    }
}

import Foundation

public struct BrowserSpec: Codable, Sendable {
    public let version: String
    public let task: BrowserTask

    public init(version: String = "ztp-browser/0.1", task: BrowserTask) {
        self.version = version
        self.task = task
    }
}

public struct BrowserTask: Codable, Sendable {
    public let action: String
    public let url: String
    public let wait: WaitConfig?
    public let viewport: ViewportConfig?
    public let output: String?
    /// Custom HTTP request headers (e.g. Authorization, Accept).
    public let headers: [String: String]?

    public init(
        action: String,
        url: String,
        wait: WaitConfig? = nil,
        viewport: ViewportConfig? = nil,
        output: String? = nil,
        headers: [String: String]? = nil
    ) {
        self.action = action
        self.url = url
        self.wait = wait
        self.viewport = viewport
        self.output = output
        self.headers = headers
    }
}

public struct WaitConfig: Codable, Sendable {
    public let strategy: String?
    public let timeoutMs: Int?

    public init(strategy: String? = nil, timeoutMs: Int? = nil) {
        self.strategy = strategy
        self.timeoutMs = timeoutMs
    }

    enum CodingKeys: String, CodingKey {
        case strategy
        case timeoutMs = "timeout_ms"
    }
}

public struct ViewportConfig: Codable, Sendable {
    public let width: Int?
    public let height: Int?
    public let scale: Int?

    public init(width: Int? = nil, height: Int? = nil, scale: Int? = nil) {
        self.width = width
        self.height = height
        self.scale = scale
    }
}

public enum BrowserSpecError: Error, Sendable {
    case invalidAction(String)
    case invalidURL(String)
    case unsupportedVersion(String)
}

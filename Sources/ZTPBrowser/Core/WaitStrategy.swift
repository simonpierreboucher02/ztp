import Foundation

public enum WaitStrategy: String, Codable, Sendable, Equatable {
    case domReady = "dom-ready"
    case networkIdle = "network-idle"
    case timeout
}

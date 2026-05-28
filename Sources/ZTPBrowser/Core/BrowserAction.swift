import Foundation

public enum BrowserAction: String, Codable, Sendable, Equatable {
    case screenshot
    case pdf
    case html
    case text
    case links
    case metadata
    case open
    case inspect
}

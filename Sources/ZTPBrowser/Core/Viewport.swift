import Foundation

public struct Viewport: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let scale: Int

    public init(width: Int = 1440, height: Int = 900, scale: Int = 2) {
        self.width = width
        self.height = height
        self.scale = scale
    }

    public static let desktop = Viewport(width: 1440, height: 900)
    public static let mobile = Viewport(width: 390, height: 844)
    public static let tablet = Viewport(width: 1024, height: 768)
}

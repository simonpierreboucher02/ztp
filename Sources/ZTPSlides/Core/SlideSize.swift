import Foundation

/// Represents slide dimensions in EMU (English Metric Units).
/// 1 inch = 914400 EMU. 1 point = 12700 EMU.
public struct SlideSize: Codable, Sendable, Equatable {
    /// Width in EMU.
    public let width: Int64
    /// Height in EMU.
    public let height: Int64

    /// Standard 16:9 widescreen slide (12192000 x 6858000 EMU).
    public static let widescreen = SlideSize(width: 12_192_000, height: 6_858_000)

    /// Standard 4:3 slide (9144000 x 6858000 EMU).
    public static let standard = SlideSize(width: 9_144_000, height: 6_858_000)

    public init(width: Int64, height: Int64) {
        self.width = width
        self.height = height
    }

    /// Initialize from an aspect ratio string.
    /// Supported values: `"16:9"`, `"4:3"`.
    public init?(aspect: String) {
        switch aspect {
        case "16:9":
            self = .widescreen
        case "4:3":
            self = .standard
        default:
            return nil
        }
    }
}

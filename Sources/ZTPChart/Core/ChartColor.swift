import Foundation

public struct ChartColor: Codable, Sendable, Equatable, Hashable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = max(0, min(1, r))
        self.g = max(0, min(1, g))
        self.b = max(0, min(1, b))
        self.a = max(0, min(1, a))
    }

    public init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") {
            cleaned = String(cleaned.dropFirst())
        }
        guard cleaned.count == 6 else { return nil }
        var hexValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&hexValue) else { return nil }
        self.r = Double((hexValue >> 16) & 0xFF) / 255.0
        self.g = Double((hexValue >> 8) & 0xFF) / 255.0
        self.b = Double(hexValue & 0xFF) / 255.0
        self.a = 1.0
    }

    public var hexString: String {
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }

    public var cssRGBA: String {
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return "rgba(\(ri),\(gi),\(bi),\(a))"
    }

    // MARK: - Predefined Colors

    public static let black = ChartColor(r: 0, g: 0, b: 0)
    public static let white = ChartColor(r: 1, g: 1, b: 1)
    public static let transparent = ChartColor(r: 0, g: 0, b: 0, a: 0)
    public static let defaultAccent = ChartColor(hex: "2563EB")!
}

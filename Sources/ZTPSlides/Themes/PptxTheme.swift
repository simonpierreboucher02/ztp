import Foundation

/// Theme configuration controlling visual appearance of a presentation.
public struct PptxTheme: Codable, Sendable, Equatable {
    /// Theme name identifier.
    public let name: String
    /// Font family name.
    public let font: String
    /// Accent color as a hex string (no "#" prefix).
    public let accent: String
    /// Optional background color as a hex string (no "#" prefix).
    public let background: String?
    /// Optional text color as a hex string (no "#" prefix).
    public let textColor: String?

    public init(
        name: String = "zyquo-business",
        font: String = "Aptos",
        accent: String = "3B82F6",
        background: String? = nil,
        textColor: String? = nil
    ) {
        self.name = name
        self.font = font
        self.accent = accent
        self.background = background
        self.textColor = textColor
    }

    /// The default theme used when none is specified.
    public static let defaultTheme = PptxTheme()
}

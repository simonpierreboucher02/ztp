import Foundation

// MARK: - Theme Inspector

public struct ThemeInspector: Sendable {

    // MARK: - Theme Info

    public struct ThemeInfo: Codable, Sendable {
        public let name: String
        public let background: String   // hex color string
        public let font: String
        public let paletteSize: Int

        public init(name: String, background: String, font: String, paletteSize: Int) {
            self.name = name
            self.background = background
            self.font = font
            self.paletteSize = paletteSize
        }
    }

    // MARK: - List All Themes

    public static func listThemes() -> [ThemeInfo] {
        return ChartTheme.allThemes.map { theme in
            ThemeInfo(
                name: theme.name,
                background: "#\(theme.background.hexString)",
                font: theme.font,
                paletteSize: theme.palette.count
            )
        }
    }
}

import Foundation

public struct ChartTheme: Codable, Sendable, Equatable {
    public let name: String
    public let background: ChartColor
    public let textColor: ChartColor
    public let gridColor: ChartColor
    public let axisColor: ChartColor
    public let font: String
    public let palette: [ChartColor]

    public init(
        name: String,
        background: ChartColor = .white,
        textColor: ChartColor = .black,
        gridColor: ChartColor,
        axisColor: ChartColor,
        font: String = "Helvetica",
        palette: [ChartColor]
    ) {
        self.name = name
        self.background = background
        self.textColor = textColor
        self.gridColor = gridColor
        self.axisColor = axisColor
        self.font = font
        self.palette = palette
    }

    // MARK: - Color Lookup

    public func color(for seriesIndex: Int) -> ChartColor {
        guard !palette.isEmpty else { return .defaultAccent }
        return palette[seriesIndex % palette.count]
    }

    // MARK: - Theme Registry

    public static func named(_ name: String) -> ChartTheme? {
        let key = name.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
        return allThemes.first { theme in
            let themeKey = theme.name.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
            return themeKey == key
        }
    }

    public static let allThemes: [ChartTheme] = [
        .zyquoLight, .zyquoDark,
        .financeLight, .financeDark,
        .researchPaper, .minimal, .terminal
    ]

    // MARK: - Built-in Themes

    public static let zyquoLight = ChartTheme(
        name: "zyquo-light",
        background: .white,
        textColor: ChartColor(hex: "1F2937")!,
        gridColor: ChartColor(hex: "E5E7EB")!,
        axisColor: ChartColor(hex: "6B7280")!,
        font: "Helvetica",
        palette: [
            ChartColor(hex: "2563EB")!,
            ChartColor(hex: "10B981")!,
            ChartColor(hex: "F59E0B")!,
            ChartColor(hex: "EF4444")!,
            ChartColor(hex: "8B5CF6")!,
            ChartColor(hex: "EC4899")!
        ]
    )

    public static let zyquoDark = ChartTheme(
        name: "zyquo-dark",
        background: ChartColor(hex: "1F2937")!,
        textColor: ChartColor(hex: "E5E7EB")!,
        gridColor: ChartColor(hex: "374151")!,
        axisColor: ChartColor(hex: "9CA3AF")!,
        font: "Helvetica",
        palette: [
            ChartColor(hex: "2563EB")!,
            ChartColor(hex: "10B981")!,
            ChartColor(hex: "F59E0B")!,
            ChartColor(hex: "EF4444")!,
            ChartColor(hex: "8B5CF6")!,
            ChartColor(hex: "EC4899")!
        ]
    )

    public static let financeLight = ChartTheme(
        name: "finance-light",
        background: ChartColor(hex: "FAFBFC")!,
        textColor: ChartColor(hex: "2D3748")!,
        gridColor: ChartColor(hex: "E2E8F0")!,
        axisColor: ChartColor(hex: "718096")!,
        font: "Helvetica",
        palette: [
            ChartColor(hex: "2B6CB0")!,
            ChartColor(hex: "718096")!,
            ChartColor(hex: "38A169")!,
            ChartColor(hex: "C53030")!,
            ChartColor(hex: "D69E2E")!,
            ChartColor(hex: "805AD5")!
        ]
    )

    public static let financeDark = ChartTheme(
        name: "finance-dark",
        background: ChartColor(hex: "171923")!,
        textColor: ChartColor(hex: "E2E8F0")!,
        gridColor: ChartColor(hex: "2D3748")!,
        axisColor: ChartColor(hex: "A0AEC0")!,
        font: "Helvetica",
        palette: [
            ChartColor(hex: "63B3ED")!,
            ChartColor(hex: "A0AEC0")!,
            ChartColor(hex: "68D391")!,
            ChartColor(hex: "FC8181")!,
            ChartColor(hex: "F6E05E")!,
            ChartColor(hex: "B794F4")!
        ]
    )

    public static let researchPaper = ChartTheme(
        name: "research-paper",
        background: .white,
        textColor: ChartColor(hex: "1A1A1A")!,
        gridColor: ChartColor(hex: "D4D4D4")!,
        axisColor: ChartColor(hex: "333333")!,
        font: "Times New Roman",
        palette: [
            ChartColor(hex: "000000")!,
            ChartColor(hex: "555555")!,
            ChartColor(hex: "999999")!,
            ChartColor(hex: "333333")!,
            ChartColor(hex: "777777")!,
            ChartColor(hex: "BBBBBB")!
        ]
    )

    public static let minimal = ChartTheme(
        name: "minimal",
        background: .white,
        textColor: ChartColor(hex: "374151")!,
        gridColor: ChartColor(hex: "F3F4F6")!,
        axisColor: ChartColor(hex: "D1D5DB")!,
        font: "Helvetica",
        palette: [
            ChartColor(hex: "2563EB")!,
            ChartColor(hex: "93C5FD")!,
            ChartColor(hex: "BFDBFE")!,
            ChartColor(hex: "1D4ED8")!,
            ChartColor(hex: "60A5FA")!,
            ChartColor(hex: "DBEAFE")!
        ]
    )

    public static let terminal = ChartTheme(
        name: "terminal",
        background: ChartColor(hex: "0D1117")!,
        textColor: ChartColor(hex: "00FF41")!,
        gridColor: ChartColor(hex: "1B2332")!,
        axisColor: ChartColor(hex: "00CC33")!,
        font: "Courier",
        palette: [
            ChartColor(hex: "00FF41")!,
            ChartColor(hex: "00CCFF")!,
            ChartColor(hex: "FF6600")!,
            ChartColor(hex: "FFFF00")!,
            ChartColor(hex: "FF0066")!,
            ChartColor(hex: "CC00FF")!
        ]
    )
}

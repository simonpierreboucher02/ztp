import Foundation

public struct TitleRenderer: Sendable {

    /// Renders a centered title and optional subtitle at the top of the chart.
    public static func render(
        title: String?,
        subtitle: String?,
        layout: ChartLayout,
        theme: ChartTheme
    ) -> [DrawingCommand] {
        var commands: [DrawingCommand] = []

        let centerX = layout.totalWidth / 2.0

        // Use title area if available, otherwise default positions
        let titleBaseY: Double
        if let area = layout.titleArea {
            titleBaseY = area.y
        } else {
            titleBaseY = 0
        }

        if let title = title, !title.isEmpty {
            let titleY = titleBaseY + 28
            commands.append(.text(
                x: centerX,
                y: titleY,
                content: title,
                fontSize: 20,
                color: theme.textColor,
                anchor: .middle,
                baseline: .alphabetic,
                bold: true,
                rotation: nil
            ))

            if let subtitle = subtitle, !subtitle.isEmpty {
                let subtitleY = titleY + 22
                commands.append(.text(
                    x: centerX,
                    y: subtitleY,
                    content: subtitle,
                    fontSize: 14,
                    color: theme.textColor,
                    anchor: .middle,
                    baseline: .alphabetic,
                    bold: false,
                    rotation: nil
                ))
            }
        } else if let subtitle = subtitle, !subtitle.isEmpty {
            let subtitleY = titleBaseY + 24
            commands.append(.text(
                x: centerX,
                y: subtitleY,
                content: subtitle,
                fontSize: 14,
                color: theme.textColor,
                anchor: .middle,
                baseline: .alphabetic,
                bold: false,
                rotation: nil
            ))
        }

        return commands
    }
}

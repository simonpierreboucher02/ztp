import Testing
import Foundation
@testable import ZTPChart
@testable import ZTPProtocols

@Suite("ZTPChart Tool Tests")
struct ZTPChartTests {

    @Test("Manifest has correct name and capabilities")
    func manifest() {
        let tool = ZTPChartTool()
        #expect(tool.manifest.name == "ztp-chart")
        #expect(tool.manifest.version == "0.1.0")
        #expect(tool.manifest.capabilities.contains("chart.create"))
        #expect(tool.manifest.capabilities.contains("chart.export.png"))
        #expect(tool.manifest.capabilities.contains("chart.export.svg"))
        #expect(tool.manifest.capabilities.contains("chart.export.pdf"))
    }

    @Test("Execute without command returns error")
    func noCommand() async throws {
        let tool = ZTPChartTool()
        let result = try await tool.execute(input: ToolInput(), context: ToolContext())
        #expect(result.ok == false)
    }

    @Test("Linear scale ticks")
    func linearScale() {
        let scale = LinearScale(values: [0, 100])
        let ticks = scale.ticks(count: 5)
        #expect(ticks.count > 0)
        #expect(ticks.first! >= scale.domainMin)
        #expect(ticks.last! <= scale.domainMax)
    }

    @Test("Categorical scale positioning")
    func categoricalScale() {
        let scale = CategoricalScale(categories: ["A", "B", "C"])
        let bw = scale.bandWidth(rangeStart: 0, rangeEnd: 300)
        #expect(bw == 100)
    }

    @Test("ChartColor hex parsing")
    func colorHex() {
        let color = ChartColor(hex: "#3B82F6")!
        #expect(color.hexString == "3B82F6")
        let noHash = ChartColor(hex: "FF0000")!
        #expect(noHash.r == 1.0)
    }

    @Test("Theme lookup")
    func themeLookup() {
        #expect(ChartTheme.named("zyquo-light") != nil)
        #expect(ChartTheme.named("zyquo-dark") != nil)
        #expect(ChartTheme.named("nonexistent") == nil)
        #expect(ChartTheme.allThemes.count == 7)
    }

    @Test("Inspector data summary")
    func dataSummary() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"line","width":800,"height":600},
         "data":{"values":[{"x":1,"y":10},{"x":2,"y":20},{"x":3,"y":30}]},
         "x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let summary = try ChartInspector.dataSummary(jsonData: Data(json.utf8), basePath: nil)
        #expect(summary.rowCount == 3)
        #expect(summary.columns.count >= 2)
    }
}

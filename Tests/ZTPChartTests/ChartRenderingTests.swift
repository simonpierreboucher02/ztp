import Testing
import Foundation
@testable import ZTPChart

@Suite("Chart Rendering Tests")
struct ChartRenderingTests {

    private func lineSpec() throws -> ChartSpec {
        let json = """
        {
          "version": "ztp-chart/0.1",
          "chart": { "type": "line", "title": "Test", "width": 800, "height": 600 },
          "data": { "values": [{ "x": 1, "y": 10 }, { "x": 2, "y": 20 }, { "x": 3, "y": 15 }] },
          "x": { "field": "x", "label": "X" },
          "y": { "label": "Y" },
          "series": [{ "field": "y", "label": "Value" }],
          "legend": true, "grid": true
        }
        """
        return try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
    }

    @Test("Build SVG chart")
    func buildSVG() throws {
        let spec = try lineSpec()
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        #expect(result.format == .svg)
        #expect(result.data.count > 0)
        let svg = String(data: result.data, encoding: .utf8)!
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test("Build PNG chart")
    func buildPNG() throws {
        let spec = try lineSpec()
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .png)
        #expect(result.format == .png)
        #expect(result.data.count > 0)
        #expect(result.data[0] == 0x89) // PNG magic byte
    }

    @Test("Build PDF chart")
    func buildPDF() throws {
        let spec = try lineSpec()
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .pdf)
        #expect(result.format == .pdf)
        #expect(result.data.count > 0)
        let header = String(data: result.data.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    @Test("Build bar chart SVG")
    func barChart() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"bar","width":600,"height":400},
         "data":{"values":[{"cat":"A","val":10},{"cat":"B","val":20}]},
         "x":{"field":"cat"},"series":[{"field":"val"}]}
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        #expect(result.chartType == .bar)
        #expect(result.data.count > 0)
    }

    @Test("Build scatter chart")
    func scatterChart() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"scatter","width":600,"height":400},
         "data":{"values":[{"x":1,"y":2},{"x":3,"y":4},{"x":5,"y":1}]},
         "x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        #expect(result.chartType == .scatter)
    }

    @Test("Build area chart")
    func areaChart() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"area","width":600,"height":400},
         "data":{"values":[{"x":1,"y":10},{"x":2,"y":20},{"x":3,"y":15}]},
         "x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        #expect(result.chartType == .area)
    }

    @Test("Build pie chart")
    func pieChart() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"pie","width":600,"height":600},
         "data":{"values":[{"seg":"A","val":30},{"seg":"B","val":50},{"seg":"C","val":20}]},
         "label_field":"seg","value_field":"val"}
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        #expect(result.chartType == .pie)
    }

    @Test("Theme selection works")
    func themeSelection() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"line","theme":"zyquo-dark","width":600,"height":400},
         "data":{"values":[{"x":1,"y":2}]},
         "x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        let svg = String(data: result.data, encoding: .utf8)!
        #expect(svg.contains("1F2937") || svg.contains("1f2937"))
    }

    @Test("Chart metadata in result")
    func metadata() throws {
        let spec = try lineSpec()
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .png)
        #expect(result.width == 800)
        #expect(result.height == 600)
        #expect(result.chartType == .line)
        #expect(result.pointsRendered > 0)
    }
}

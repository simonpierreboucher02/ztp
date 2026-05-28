import Testing
import Foundation
@testable import ZTPChart

@Suite("ChartSpec Tests")
struct ChartSpecTests {

    @Test("Decode line chart spec")
    func decodeLineSpec() throws {
        let json = """
        {
          "version": "ztp-chart/0.1",
          "chart": { "type": "line", "title": "Test", "width": 800, "height": 600 },
          "data": { "values": [{ "x": 1, "y": 10 }, { "x": 2, "y": 20 }] },
          "x": { "field": "x" },
          "series": [{ "field": "y", "label": "Y" }]
        }
        """
        let spec = try JSONDecoder().decode(ChartSpec.self, from: Data(json.utf8))
        #expect(spec.version == "ztp-chart/0.1")
        #expect(spec.chart.type == .line)
        #expect(spec.chart.width == 800)
    }

    @Test("Valid spec passes validation")
    func validSpec() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"line","width":800,"height":600},"data":{"values":[{"x":1,"y":2}]},"x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let result = ChartSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid version fails")
    func invalidVersion() throws {
        let json = """
        {"version":"wrong","chart":{"type":"line"},"data":{"values":[{"x":1}]},"x":{"field":"x"},"series":[{"field":"x"}]}
        """
        let result = ChartSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(!result.valid)
    }

    @Test("Missing data fails")
    func missingData() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"line","width":800,"height":600},"x":{"field":"x"},"series":[{"field":"y"}]}
        """
        let result = ChartSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(!result.valid)
    }

    @Test("Invalid JSON fails gracefully")
    func invalidJSON() {
        let result = ChartSpecValidator.validate(jsonData: Data("not json".utf8))
        #expect(!result.valid)
    }
}

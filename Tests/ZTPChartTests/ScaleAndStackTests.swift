import Testing
import Foundation
@testable import ZTPChart

@Suite("Log Scale & Stacking Tests")
struct ScaleAndStackTests {

    @Test("makeScale returns a LogScale for type=log")
    func logSelected() {
        let s = ChartEngine.makeScale(values: [1, 10, 100], axis: AxisSpec(type: "log"))
        #expect(s is LogScale)
    }

    @Test("makeScale falls back to linear for non-positive values")
    func logFallback() {
        let s = ChartEngine.makeScale(values: [0, 5, 10], axis: AxisSpec(type: "log"))
        #expect(s is LinearScale)
    }

    @Test("LogScale maps a decade to the midpoint")
    func logMapping() {
        let s = LogScale(min: 1, max: 100)
        // value 10 is halfway between 10^0 and 10^2 in log space → 0.5
        let mid = s.map(10, rangeStart: 0, rangeEnd: 1)
        #expect(abs(mid - 0.5) < 0.01)
    }

    @Test("ChartSpec decodes stacked and data_labels")
    func specDecodes() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"bar","width":400,"height":300},
        "data":{"values":[{"q":"A","v":1}]},"x":{"field":"q"},"y":{"type":"log"},
        "stacked":true,"data_labels":true,"series":[{"field":"v"}]}
        """
        let spec = try ChartSpec.from(json: Data(json.utf8))
        #expect(spec.stacked == true)
        #expect(spec.dataLabels == true)
        #expect(spec.y?.type == "log")
    }

    @Test("Stacked bar chart with labels renders")
    func stackedBuilds() throws {
        let json = """
        {"version":"ztp-chart/0.1","chart":{"type":"bar","width":600,"height":400},
        "data":{"values":[{"q":"A","x":10,"y":5}]},"x":{"field":"q"},"y":{},
        "stacked":true,"data_labels":true,"series":[{"field":"x"},{"field":"y"}]}
        """
        let spec = try ChartSpec.from(json: Data(json.utf8))
        let result = try ChartEngine.build(spec: spec, basePath: nil, format: .svg)
        let svg = String(data: result.data, encoding: .utf8) ?? ""
        #expect(svg.contains(">10<"))
        #expect(svg.contains(">5<"))
    }
}

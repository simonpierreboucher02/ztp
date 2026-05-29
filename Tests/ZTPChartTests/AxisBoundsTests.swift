import Testing
import Foundation
@testable import ZTPChart

@Suite("Axis Bounds Tests")
struct AxisBoundsTests {

    @Test("Explicit min/max override the auto domain")
    func explicitBounds() {
        let s = ChartEngine.boundedScale(values: [3, 7, 42], axis: AxisSpec(min: 0, max: 100))
        #expect(s.domainMin == 0)
        #expect(s.domainMax == 100)
    }

    @Test("Only min provided keeps auto max")
    func partialMin() {
        let auto = ChartEngine.boundedScale(values: [10, 20, 30], axis: nil)
        let s = ChartEngine.boundedScale(values: [10, 20, 30], axis: AxisSpec(min: 0))
        #expect(s.domainMin == 0)
        #expect(s.domainMax == auto.domainMax)
    }

    @Test("No axis falls back to auto-fitted domain")
    func noAxis() {
        let s = ChartEngine.boundedScale(values: [1, 2, 3], axis: nil)
        #expect(s.domainMin <= 1)
        #expect(s.domainMax >= 3)
    }

    @Test("Inverted bounds are corrected")
    func inverted() {
        let s = ChartEngine.boundedScale(values: [5], axis: AxisSpec(min: 100, max: 0))
        #expect(s.domainMax > s.domainMin)
    }
}

import Foundation

/// A base-10 logarithmic scale. Requires a strictly positive domain; the
/// factory in `ChartEngine` falls back to a linear scale when any value is
/// non-positive.
public struct LogScale: ChartScale, Sendable {
    public let domainMin: Double
    public let domainMax: Double
    private let logMin: Double
    private let logMax: Double

    public init(min: Double, max: Double) {
        let lo = Swift.max(min, 1e-9)
        let hi = Swift.max(max, lo * 10)
        self.domainMin = lo
        self.domainMax = hi
        self.logMin = log10(lo)
        self.logMax = log10(hi)
    }

    public init(values: [Double]) {
        let positives = values.filter { $0 > 0 }
        let rawMin = positives.min() ?? 1
        let rawMax = positives.max() ?? 10
        // Snap to enclosing powers of ten for clean decades.
        let lo = pow(10, floor(log10(rawMin)))
        let hi = pow(10, ceil(log10(rawMax)))
        self.init(min: lo, max: hi <= lo ? lo * 10 : hi)
    }

    public func map(_ value: Double, rangeStart: Double, rangeEnd: Double) -> Double {
        guard value > 0 else { return rangeStart }
        let span = logMax - logMin
        guard span != 0 else { return rangeStart }
        let t = (log10(value) - logMin) / span
        return rangeStart + t * (rangeEnd - rangeStart)
    }

    public func ticks(count: Int) -> [Double] {
        // One tick per power of ten across the domain.
        var result: [Double] = []
        var exp = floor(logMin)
        while exp <= ceil(logMax) + 1e-9 {
            let v = pow(10, exp)
            if v >= domainMin - 1e-9 && v <= domainMax + 1e-9 {
                result.append(v)
            }
            exp += 1
        }
        return result.isEmpty ? [domainMin, domainMax] : result
    }

    public func label(for value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1 && value == value.rounded() && absValue < 1e15 {
            return LinearScale.formatWithCommas(Int(value))
        }
        if absValue > 0 && absValue < 1 {
            return String(format: "%g", value)
        }
        return String(format: "%g", value)
    }
}

import Foundation

public struct LinearScale: ChartScale, Sendable {
    public let domainMin: Double
    public let domainMax: Double

    public init(min: Double, max: Double) {
        self.domainMin = min
        self.domainMax = max
    }

    public init(values: [Double], padding: Double = 0.05) {
        guard !values.isEmpty else {
            self.domainMin = 0
            self.domainMax = 1
            return
        }
        let rawMin = values.min()!
        let rawMax = values.max()!
        let span = rawMax - rawMin
        if span == 0 {
            // All values are the same; create a range around the value
            let v = rawMin
            if v == 0 {
                self.domainMin = 0
                self.domainMax = 1
            } else {
                self.domainMin = v - abs(v) * 0.1
                self.domainMax = v + abs(v) * 0.1
            }
        } else {
            let pad = span * padding
            let lo = rawMin - pad
            let hi = rawMax + pad
            // Snap to nice boundaries
            let step = LinearScale.niceStep(for: hi - lo, targetCount: 5)
            self.domainMin = floor(lo / step) * step
            self.domainMax = ceil(hi / step) * step
        }
    }

    // MARK: - Mapping

    public func map(_ value: Double, rangeStart: Double, rangeEnd: Double) -> Double {
        let domainSpan = domainMax - domainMin
        guard domainSpan != 0 else { return rangeStart }
        let t = (value - domainMin) / domainSpan
        return rangeStart + t * (rangeEnd - rangeStart)
    }

    // MARK: - Ticks

    public func ticks(count: Int = 5) -> [Double] {
        let targetCount = Swift.max(count, 2)
        let span = domainMax - domainMin
        guard span > 0 else { return [domainMin] }

        let step = LinearScale.niceStep(for: span, targetCount: targetCount)
        var result: [Double] = []
        var tick = ceil(domainMin / step) * step
        // Handle floating point: ensure we start at or after domainMin
        if tick < domainMin - step * 1e-10 {
            tick += step
        }
        while tick <= domainMax + step * 1e-10 {
            result.append(tick)
            tick += step
        }
        return result
    }

    // MARK: - Label Formatting

    public func label(for value: Double) -> String {
        let absValue = abs(value)
        if absValue == 0 {
            return "0"
        }
        // Determine if the value is effectively an integer
        if absValue >= 1 && value == value.rounded() && absValue < 1e15 {
            let intVal = Int(value)
            return LinearScale.formatWithCommas(intVal)
        }
        // For decimals, use a reasonable number of decimal places
        let span = domainMax - domainMin
        let precision: Int
        if span >= 100 {
            precision = 0
        } else if span >= 1 {
            precision = 1
        } else if span >= 0.1 {
            precision = 2
        } else {
            precision = 3
        }
        let formatted = String(format: "%.\(precision)f", value)
        // Remove trailing zeros after decimal point (but keep at least one if there's a dot)
        if formatted.contains(".") {
            var trimmed = formatted
            while trimmed.hasSuffix("0") {
                trimmed = String(trimmed.dropLast())
            }
            if trimmed.hasSuffix(".") {
                trimmed = String(trimmed.dropLast())
            }
            // Add comma formatting for the integer part
            if let dotIndex = formatted.firstIndex(of: ".") {
                let intPart = String(formatted[formatted.startIndex..<dotIndex])
                if let intValue = Int(intPart), abs(intValue) >= 1000 {
                    let decPart = String(trimmed[trimmed.index(after: (trimmed.firstIndex(of: ".") ?? trimmed.endIndex))...])
                    if decPart.isEmpty {
                        return LinearScale.formatWithCommas(intValue)
                    }
                    return LinearScale.formatWithCommas(intValue) + "." + decPart
                }
            }
            return trimmed
        }
        return formatted
    }

    // MARK: - Internal Helpers

    private static func niceStep(for range: Double, targetCount: Int) -> Double {
        let rawStep = range / Double(targetCount)
        let magnitude = pow(10, floor(log10(rawStep)))
        let normalized = rawStep / magnitude

        let niceNormalized: Double
        if normalized <= 1.0 {
            niceNormalized = 1.0
        } else if normalized <= 2.0 {
            niceNormalized = 2.0
        } else if normalized <= 5.0 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }
        return niceNormalized * magnitude
    }

    static func formatWithCommas(_ value: Int) -> String {
        let isNegative = value < 0
        var absValue = abs(value)
        var parts: [String] = []
        if absValue == 0 { return "0" }
        while absValue > 0 {
            let chunk = absValue % 1000
            absValue /= 1000
            if absValue > 0 {
                parts.append(String(format: "%03d", chunk))
            } else {
                parts.append(String(chunk))
            }
        }
        let result = parts.reversed().joined(separator: ",")
        return isNegative ? "-" + result : result
    }
}

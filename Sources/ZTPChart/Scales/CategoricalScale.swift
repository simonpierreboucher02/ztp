import Foundation

public struct CategoricalScale: Sendable {
    public let categories: [String]

    public init(categories: [String]) {
        self.categories = categories
    }

    /// Returns the center position for the category at the given index within the range.
    public func position(for index: Int, rangeStart: Double, rangeEnd: Double) -> Double {
        let count = categories.count
        guard count > 0 else { return rangeStart }
        let band = bandWidth(rangeStart: rangeStart, rangeEnd: rangeEnd)
        return rangeStart + (Double(index) + 0.5) * band
    }

    /// Returns the width of each category band.
    public func bandWidth(rangeStart: Double, rangeEnd: Double) -> Double {
        let count = categories.count
        guard count > 0 else { return rangeEnd - rangeStart }
        return (rangeEnd - rangeStart) / Double(count)
    }
}

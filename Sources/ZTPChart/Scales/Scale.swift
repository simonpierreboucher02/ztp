import Foundation

public protocol ChartScale: Sendable {
    func map(_ value: Double, rangeStart: Double, rangeEnd: Double) -> Double
    var domainMin: Double { get }
    var domainMax: Double { get }
    func ticks(count: Int) -> [Double]
    func label(for value: Double) -> String
}

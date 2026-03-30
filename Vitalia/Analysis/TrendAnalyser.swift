import Foundation

/// Derives a trend direction from a time-ordered array of values.
enum TrendAnalyser {

    /// Compares the mean of the most recent `recentWindow` values against
    /// the mean of the preceding `baselineWindow` values.
    static func direction(
        from values: [Double],
        recentWindow: Int = 3,
        baselineWindow: Int = 7,
        threshold: Double = 0.03     // 3% relative change required to call a trend
    ) -> TrendDirection {
        guard values.count >= 2 else { return .stable }

        let recent   = Array(values.suffix(recentWindow))
        let baseline = values.count > recentWindow
            ? Array(values.dropLast(recentWindow).suffix(baselineWindow))
            : Array(values.prefix(1))

        let recentMean   = recent.reduce(0, +) / Double(recent.count)
        let baselineMean = baseline.reduce(0, +) / Double(baseline.count)

        guard baselineMean > 0 else { return .stable }
        let change = (recentMean - baselineMean) / baselineMean

        if change >  threshold { return .up }
        if change < -threshold { return .down }
        return .stable
    }

    /// For metrics where lower is better (RHR, BP, awake%), invert the direction.
    static func directionForMetric(
        _ definition: MetricDefinition,
        values: [Double]
    ) -> TrendDirection {
        let raw = direction(from: values)
        // If higher is worse, flip up/down
        if !definition.higherIsBetter {
            switch raw {
            case .up:   return .down
            case .down: return .up
            case .stable: return .stable
            }
        }
        return raw
    }
}

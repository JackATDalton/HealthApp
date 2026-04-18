import Foundation

/// Maps a raw metric value to a 0–100 score and MetricStatus using non-linear decay.
enum MetricEvaluator {

    struct Result {
        let score: Double           // 0–100
        let status: MetricStatus
        let progress: Double        // 0–1 fill for the progress bar
    }

    static func evaluate(
        _ value: Double,
        definition: MetricDefinition,
        customLow: Double? = nil,
        customHigh: Double? = nil
    ) -> Result {
        let low  = customLow  ?? definition.optimalLow
        let high = customHigh ?? definition.optimalHigh

        let score    = computeScore(value: value, low: low, high: high, higherIsBetter: definition.higherIsBetter)
        let status   = statusFromScore(score)
        let progress = computeProgress(value: value, low: low, high: high, higherIsBetter: definition.higherIsBetter)

        return Result(score: score, status: status, progress: progress)
    }

    // MARK: - Score (0–100)

    static func computeScore(value: Double, low: Double?, high: Double?, higherIsBetter: Bool) -> Double {
        // Within range → perfect
        if let lo = low, let hi = high {
            if value >= lo && value <= hi { return 100 }
        } else if let lo = low, high == nil {
            if value >= lo { return 100 }           // only lower bound — at or above is optimal
        } else if let hi = high, low == nil {
            if value <= hi { return 100 }           // only upper bound — at or below is optimal
        } else {
            return 75                                // no bounds — neutral score
        }

        let deviation = computeDeviation(value: value, low: low, high: high)

        // Non-linear piecewise decay
        let score: Double
        if deviation <= 0.10 {
            score = 100 - deviation * 200           // 100 → 80
        } else if deviation <= 0.30 {
            score = 80 - (deviation - 0.10) * 150  // 80 → 50
        } else if deviation <= 0.60 {
            score = 50 - (deviation - 0.30) * 100  // 50 → 20
        } else {
            score = max(0, 20 - (deviation - 0.60) * 50)
        }
        return max(0, min(100, score))
    }

    // MARK: - Status from score

    static func statusFromScore(_ score: Double) -> MetricStatus {
        if score >= 90 { return .excellent }
        if score >= 75 { return .optimal }
        if score >= 50 { return .borderline }
        return .outOfRange
    }

    // MARK: - Progress bar fill (0–1)

    static func computeProgress(value: Double, low: Double?, high: Double?, higherIsBetter: Bool) -> Double {
        if let lo = low, let hi = high {
            // Position within [lo, hi], clamped
            return max(0, min(1, (value - lo) / (hi - lo)))
        } else if let lo = low {
            // Higher is better: fill proportionally up to 1.5× target
            return max(0, min(1, value / (lo * 1.5)))
        } else if let hi = high {
            // Lower is better: fill inversely
            return max(0, min(1, 1.0 - value / (hi * 1.5)))
        }
        return 0.5
    }

    // MARK: - Private

    private static func computeDeviation(value: Double, low: Double?, high: Double?) -> Double {
        if let lo = low, value < lo {
            return lo > 0 ? (lo - value) / lo : 0
        }
        if let hi = high, value > hi {
            return hi > 0 ? (value - hi) / hi : 0
        }
        return 0
    }
}

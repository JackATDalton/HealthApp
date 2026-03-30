import Foundation

/// Computes the aggregate Longevity Score (0–100) from per-metric scores.
/// Formula: evidence-weighted average (Tier 1 = 3×, Tier 2 = 2×, Tier 3 = 1×)
enum LongevityScoreCalculator {

    struct MetricScore: Identifiable {
        let id: String                  // MetricDefinition.id
        let displayName: String
        let tier: EvidenceTier
        let score: Double               // 0–100
        let rawValue: Double?
        let status: MetricStatus
    }

    struct Result {
        let score: Double
        let weightedAverage: Double
        let metricScores: [MetricScore]
    }

    /// Metrics excluded from Longevity Score (shown in dashboard but not factored into score).
    private static let excludedFromScore: Set<String> = ["body_weight_trend"]

    static func calculate(
        snapshot: [String: Double],
        configs: [MetricConfig]
    ) -> Result {
        let enabledConfigs = Dictionary(
            uniqueKeysWithValues: configs.map { ($0.metricID, $0) }
        )

        var scores: [MetricScore] = []

        for def in MetricDefinition.all {
            // Skip if explicitly excluded from longevity score
            if excludedFromScore.contains(def.id) { continue }
            // Skip if explicitly disabled
            let config = enabledConfigs[def.id]
            if config?.isEnabled == false { continue }

            // HRV: compare 30-day average to all-time average to detect long-term decline/improvement.
            // Recovery score continues to use overnight vs 30-day baseline (unchanged).
            if def.id == "hrv" {
                guard let current  = snapshot["hrv_baseline"],
                      let longterm = snapshot["hrv_longterm_baseline"],
                      longterm > 0
                else { continue }

                let evalResult = MetricEvaluator.evaluate(
                    current,
                    definition: def,
                    customLow:  longterm,
                    customHigh: nil
                )
                scores.append(MetricScore(
                    id:          def.id,
                    displayName: def.displayName,
                    tier:        def.evidenceTier,
                    score:       evalResult.score,
                    rawValue:    current,
                    status:      evalResult.status
                ))
                continue
            }

            guard let value = snapshot[def.id] else { continue }

            // Don't score metrics without any bounds via this path (training_load is contextual)
            let hasAnyBound = def.optimalLow != nil || def.optimalHigh != nil
            guard hasAnyBound else { continue }

            let evalResult = MetricEvaluator.evaluate(
                value,
                definition: def,
                customLow:  config?.customRangeLow,
                customHigh: config?.customRangeHigh
            )

            scores.append(MetricScore(
                id:          def.id,
                displayName: def.displayName,
                tier:        def.evidenceTier,
                score:       evalResult.score,
                rawValue:    value,
                status:      evalResult.status
            ))
        }

        guard !scores.isEmpty else {
            return Result(score: 0, weightedAverage: 0, metricScores: [])
        }

        // Evidence-weighted average: Tier 1 = weight 3, Tier 2 = 2, Tier 3 = 1
        var weightedSum = 0.0
        var totalWeight = 0.0
        for ms in scores {
            let w = ms.tier.weight
            weightedSum += ms.score * w
            totalWeight += w
        }
        let weightedAverage = totalWeight > 0 ? weightedSum / totalWeight : 0
        let finalScore = weightedAverage.rounded()

        return Result(
            score: max(0, min(100, finalScore)),
            weightedAverage: weightedAverage,
            metricScores: scores.sorted { $0.score < $1.score }   // worst first
        )
    }
}

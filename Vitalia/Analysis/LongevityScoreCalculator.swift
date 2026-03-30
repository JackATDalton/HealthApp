import Foundation

/// Computes the aggregate Longevity Score (0–100) from per-metric scores.
/// Formula: min(Tier1_scores) × 0.5 + evidence_weighted_average × 0.5
/// A single bad Tier 1 metric caps the total.
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
        let minTier1Score: Double
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
            return Result(score: 0, weightedAverage: 0, minTier1Score: 100, metricScores: [])
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

        // Tier 1 outlier penalty
        let tier1Scores = scores.filter { $0.tier == .tier1 }.map(\.score)
        let minTier1 = tier1Scores.isEmpty ? 100.0 : tier1Scores.min()!

        // spec formula: min(Tier1) × 0.5 + weighted_average × 0.5
        let finalScore = (minTier1 * 0.5 + weightedAverage * 0.5).rounded()

        return Result(
            score: max(0, min(100, finalScore)),
            weightedAverage: weightedAverage,
            minTier1Score: minTier1,
            metricScores: scores.sorted { $0.score < $1.score }   // worst first
        )
    }
}

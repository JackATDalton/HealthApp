import Foundation

enum PromptBuilder {

    // All valid metric IDs Claude can reference as the focus metric
    private static let validMetricIDs = MetricDefinition.all.map(\.id).joined(separator: ", ")

    // MARK: - Entry point

    /// Returns (systemPrompt, userMessage) ready to send to Claude.
    static func build(
        snapshot: [String: Double],
        recoveryResult: RecoveryScoreResult?,
        longevityResult: LongevityScoreCalculator.Result?,
        profile: UserProfile?,
        configs: [MetricConfig]
    ) -> (system: String, userMessage: String) {
        (systemPrompt, userMessage(
            snapshot: snapshot,
            recoveryResult: recoveryResult,
            longevityResult: longevityResult,
            profile: profile,
            configs: configs
        ))
    }

    // MARK: - System prompt

    private static let systemPrompt = """
    You are an expert longevity physician-coach specialising in preventive medicine, exercise physiology, and health optimisation. You analyse Apple Watch and HealthKit data to write personalised, evidence-based longevity plans.

    Core rules:
    - Reference the user's actual metric values in every recommendation ("your VO₂ Max of 42 mL/kg/min…")
    - Prioritise Tier 1 metrics — they carry the strongest longevity evidence
    - Every recommendation must be specific and actionable — never generic
    - Write in second person. Be direct, motivating, and clinically grounded
    - Aim for around 700 words total across all sections

    Structure your response with exactly these section headers on their own line:

    ## Priority Interventions
    ## 90-Day Action Plan
    ## Quick Wins
    ## Focus Metric
    ## Weekly Workout Plan

    In the Focus Metric section, your very first line must be:
    metric_id: [id]
    where [id] is one of the metric IDs listed in the user message. Then explain why this metric is your primary focus and give 2–3 specific improvement tactics.

    In the Weekly Workout Plan section, generate a structured 7-day workout plan based on the user's recovery score, training load, and priority interventions. Use exactly this format:

    context: [one sentence explaining the plan intensity given recovery score and load]
    ### Monday
    type: [workout type, e.g. Zone 2 Run]
    duration: [e.g. 45 min]
    zones: [e.g. Zone 2 — keep HR 135–155 bpm]
    notes: [one specific coaching cue]
    ### Tuesday
    rest
    ### Wednesday
    type: [workout type]
    duration: [e.g. 30 min]
    zones: [e.g. Strength — moderate load]
    notes: [one specific coaching cue]

    ...and so on for all 7 days. Use "rest" for rest days. Distribute workouts to match the user's Zone 2 and vigorous minute targets and strength session targets.
    """

    // MARK: - User message

    private static func userMessage(
        snapshot: [String: Double],
        recoveryResult: RecoveryScoreResult?,
        longevityResult: LongevityScoreCalculator.Result?,
        profile: UserProfile?,
        configs: [MetricConfig]
    ) -> String {
        var parts: [String] = []

        parts.append("Generate my personalised longevity plan using the data below.\n")

        // Profile
        parts.append(profileSection(profile))

        // Recovery
        parts.append(recoverySection(recoveryResult))

        // Longevity score
        parts.append(longevitySection(longevityResult))

        // Metric table
        parts.append(metricTableSection(snapshot: snapshot, configs: configs))

        // Priority list (worst metrics)
        if let longevity = longevityResult, !longevity.metricScores.isEmpty {
            parts.append(prioritySection(longevity))
        }

        // Valid metric IDs for focus metric
        parts.append("\nValid metric_id values: \(validMetricIDs)")

        return parts.joined(separator: "\n")
    }

    // MARK: - Sections

    private static func profileSection(_ profile: UserProfile?) -> String {
        var lines = ["--- PROFILE ---"]
        if let p = profile {
            var profileParts: [String] = []
            if let age = p.ageYears { profileParts.append("\(age) years old") }
            if p.biologicalSex != "unknown" { profileParts.append(p.biologicalSex.capitalized) }
            if let h = p.heightCm { profileParts.append(String(format: "%.0f cm", h)) }
            if let w = p.weightKg { profileParts.append(String(format: "%.1f kg", w)) }
            if !profileParts.isEmpty { lines.append(profileParts.joined(separator: ", ")) }
            lines.append("Fitness background: \(p.fitnessBackground.rawValue)")
            lines.append("Primary goal: \(p.primaryGoal.rawValue)")
        } else {
            lines.append("Profile not set")
        }
        return lines.joined(separator: "\n")
    }

    private static func recoverySection(_ result: RecoveryScoreResult?) -> String {
        var lines = ["\n--- RECOVERY SCORE ---"]
        guard let r = result else {
            lines.append("Not available")
            return lines.joined(separator: "\n")
        }

        if r.isIncomplete {
            lines.append("Incomplete — insufficient data (\(r.incompleteReasons.joined(separator: "; ")))")
        } else {
            lines.append("Overall: \(Int(r.score))/100 — \(r.band.rawValue)")
            lines.append("Recommendation: \(r.band.recommendation)")
        }

        let inputs = r.inputs.sortedInputs
        if !inputs.isEmpty {
            lines.append("Components:")
            for input in inputs {
                let scoreStr = input.score.map { "\(Int($0.rounded()))/100" } ?? "n/a"
                let weightPct = Int((input.weight * 100).rounded())
                lines.append("  \(input.name): \(scoreStr) (weight \(weightPct)%)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func longevitySection(_ result: LongevityScoreCalculator.Result?) -> String {
        var lines = ["\n--- LONGEVITY SCORE ---"]
        guard let r = result else {
            lines.append("Not available")
            return lines.joined(separator: "\n")
        }
        lines.append("Overall: \(Int(r.score))/100")
        lines.append("Weighted average: \(Int(r.weightedAverage.rounded()))/100")
        return lines.joined(separator: "\n")
    }

    private static func metricTableSection(snapshot: [String: Double], configs: [MetricConfig]) -> String {
        var lines = ["\n--- ALL METRICS ---"]
        lines.append("Name | ID | Value | Optimal Range | Status | Tier")

        let configMap = Dictionary(uniqueKeysWithValues: configs.map { ($0.metricID, $0) })

        for def in MetricDefinition.all {
            let config = configMap[def.id]

            // Skip disabled metrics
            if config?.isEnabled == false {
                lines.append("\(def.displayName) | \(def.id) | DISABLED | — | disabled | T\(def.evidenceTier.rawValue)")
                continue
            }

            let value = snapshot[def.id]
            let valueStr = value.map { formatValue($0, metric: def) } ?? "no data"

            let low  = config?.customRangeLow  ?? def.optimalLow
            let high = config?.customRangeHigh ?? def.optimalHigh
            let rangeStr = rangeString(low: low, high: high, unit: def.unit)

            let status: String
            if let v = value {
                let score = MetricEvaluator.computeScore(
                    value: v, low: low, high: high, higherIsBetter: def.higherIsBetter
                )
                status = MetricEvaluator.statusFromScore(score).promptLabel
            } else {
                status = "no data"
            }

            lines.append("\(def.displayName) | \(def.id) | \(valueStr) \(def.unit) | \(rangeStr) | \(status) | T\(def.evidenceTier.rawValue)")
        }
        return lines.joined(separator: "\n")
    }

    private static func prioritySection(_ result: LongevityScoreCalculator.Result) -> String {
        var lines = ["\n--- PRIORITY METRICS (worst first) ---"]

        // Tier 1 worst first, then Tier 2, then Tier 3
        let sorted = result.metricScores.sorted {
            if $0.tier != $1.tier { return $0.tier.rawValue < $1.tier.rawValue }
            return $0.score < $1.score
        }

        for ms in sorted.prefix(8) {
            var line = "\(ms.displayName) (T\(ms.tier.rawValue)): score \(Int(ms.score.rounded()))/100"
            if let raw = ms.rawValue {
                if let def = MetricDefinition.all.first(where: { $0.id == ms.id }) {
                    line += " — value: \(formatValue(raw, metric: def)) \(def.unit)"
                    // Gap from optimal
                    let low  = def.optimalLow
                    let high = def.optimalHigh
                    if let lo = low, raw < lo {
                        line += " (\(formatDelta(lo - raw)) below optimal floor \(formatBound(lo)) \(def.unit))"
                    } else if let hi = high, raw > hi {
                        line += " (\(formatDelta(raw - hi)) above optimal ceiling \(formatBound(hi)) \(def.unit))"
                    }
                }
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func rangeString(low: Double?, high: Double?, unit: String) -> String {
        switch (low, high) {
        case let (lo?, hi?):   return "\(formatBound(lo))–\(formatBound(hi)) \(unit)"
        case let (lo?, nil):   return "≥ \(formatBound(lo)) \(unit)"
        case let (nil, hi?):   return "≤ \(formatBound(hi)) \(unit)"
        case (nil, nil):       return "baseline-relative"
        }
    }

    private static func formatBound(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private static func formatDelta(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private static func formatValue(_ value: Double, metric: MetricDefinition) -> String {
        switch metric.id {
        case "vo2max":          return String(format: "%.1f", value)
        case "steps":           return "\(Int(value))"
        case "sleep_duration":  return String(format: "%.1f", value)
        case "sleep_efficiency", "deep_sleep_pct", "rem_sleep_pct", "awake_pct":
            return "\(Int(value.rounded()))%"
        case "wrist_temp":      return String(format: "%+.1f°C", value)
        default:                return String(format: "%.0f", value)
        }
    }
}

// MARK: - MetricStatus prompt label

private extension MetricStatus {
    var promptLabel: String {
        switch self {
        case .optimal:    "optimal"
        case .borderline: "borderline"
        case .outOfRange: "out of range"
        case .noData:     "no data"
        case .disabled:   "disabled"
        }
    }
}

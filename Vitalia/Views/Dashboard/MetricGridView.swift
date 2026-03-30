import SwiftUI

struct MetricGridView: View {
    let snapshots: [String: Double]
    let configs: [MetricConfig]
    var evalResults: [String: MetricEvaluator.Result] = [:]
    var onMetricTap: ((MetricDefinition) -> Void)? = nil

    // Mock data for Phase 1
    static let mockSnapshots: [String: Double] = [
        "vo2max": 48.2,
        "rhr": 52,
        "hrv": 38,
        "spo2": 98,
        "steps": 9_200,
        "zone2_minutes": 140,
        "vigorous_minutes": 18,
        "strength_sessions": 2,
        "sleep_duration": 7.1,
        "sleep_efficiency": 87,
        "deep_sleep_pct": 17,
        "rem_sleep_pct": 22,
        "respiratory_rate": 14.2,
        "mindful_minutes": 0,
        "daylight_exposure": 25,
    ]

    private let columns = [
        GridItem(.flexible(), spacing: VSpacing.m),
        GridItem(.flexible(), spacing: VSpacing.m),
    ]

    private var categories: [MetricCategory] {
        MetricCategory.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.xxl) {
            ForEach(categories, id: \.self) { category in
                let metrics = MetricDefinition.all.filter { $0.category == category }
                if !metrics.isEmpty {
                    categorySection(category: category, metrics: metrics)
                }
            }
        }
    }

    private func categorySection(category: MetricCategory, metrics: [MetricDefinition]) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: category.rawValue)

            LazyVGrid(columns: columns, spacing: VSpacing.m) {
                ForEach(metrics) { metric in
                    let value     = snapshots[metric.id]
                    let config    = configs.first { $0.metricID == metric.id }
                    let isEnabled = config?.isEnabled ?? true
                    let eval      = evalResults[metric.id]
                    let status    = value == nil ? MetricStatus.noData : (eval?.status ?? evaluateStatus(metric: metric, value: value, config: config))
                    let progress  = eval?.progress ?? evaluateProgress(metric: metric, value: value, config: config)

                    Button {
                        if isEnabled { onMetricTap?(metric) }
                    } label: {
                        MetricCardView(
                            name: metric.displayName,
                            value: formatValue(value: value, metric: metric),
                            unit: metric.unit,
                            tier: metric.evidenceTier.rawValue,
                            status: status,
                            progress: progress,
                            isEnabled: isEnabled
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func evaluateStatus(metric: MetricDefinition, value: Double?, config: MetricConfig?) -> MetricStatus {
        guard let value else { return .noData }
        let low  = config?.customRangeLow  ?? metric.optimalLow
        let high = config?.customRangeHigh ?? metric.optimalHigh

        let deviation = computeDeviation(value: value, low: low, high: high)

        if deviation <= 0 { return .optimal }
        if deviation <= 0.15 { return .borderline }
        return .outOfRange
    }

    private func evaluateProgress(metric: MetricDefinition, value: Double?, config: MetricConfig?) -> Double {
        guard let value else { return 0 }
        let low  = config?.customRangeLow  ?? metric.optimalLow
        let high = config?.customRangeHigh ?? metric.optimalHigh

        if let low, let high {
            return max(0, min(1, (value - low) / (high - low)))
        } else if let low {
            return max(0, min(1, value / (low * 1.5)))
        } else if let high {
            return max(0, min(1, 1 - value / (high * 1.5)))
        }
        return 0.5
    }

    private func computeDeviation(value: Double, low: Double?, high: Double?) -> Double {
        if let low, value < low { return (low - value) / low }
        if let high, value > high { return (value - high) / high }
        return 0
    }

    private func formatValue(value: Double?, metric: MetricDefinition) -> String {
        guard let value else { return "—" }
        switch metric.id {
        case "vo2max":             return String(format: "%.1f", value)
        case "steps":              return "\(Int(value).formatted())"
        case "sleep_duration":     return String(format: "%.1f", value)
        case "sleep_efficiency", "deep_sleep_pct", "rem_sleep_pct", "awake_pct":
            return "\(Int(value.rounded()))%"
        case "hrv":                return "\(Int(value.rounded()))"
        case "zone2_minutes", "vigorous_minutes": return "\(Int(value.rounded()))"
        case "strength_sessions":  return "\(Int(value.rounded()))"
        case "daylight_exposure":  return "\(Int(value.rounded()))"
        case "wrist_temp":         return String(format: "%+.1f", value)
        case "body_weight_trend":  return String(format: "%.1f%%", value)
        default:                   return String(format: "%.0f", value)
        }
    }
}

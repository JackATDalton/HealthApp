import SwiftUI
import SwiftData
import Charts

struct MetricDetailView: View {
    let metric: MetricDefinition
    let snapshot: [String: Double]
    let evalResult: MetricEvaluator.Result?

    @Environment(\.dismiss) private var dismiss
    @Query private var dailySnapshots: [DailySnapshot]
    @Query private var metricConfigs: [MetricConfig]

    private var config: MetricConfig? {
        metricConfigs.first { $0.metricID == metric.id }
    }

    private var currentValue: Double? { snapshot[metric.id] }

    private var status: MetricStatus {
        guard let v = currentValue else { return .noData }
        return evalResult?.status ?? MetricEvaluator.statusFromScore(
            MetricEvaluator.computeScore(
                value: v,
                low: config?.customRangeLow ?? metric.optimalLow,
                high: config?.customRangeHigh ?? metric.optimalHigh,
                higherIsBetter: metric.higherIsBetter
            )
        )
    }

    private var score: Double? {
        guard let v = currentValue else { return nil }
        return evalResult?.score ?? MetricEvaluator.computeScore(
            value: v,
            low: config?.customRangeLow ?? metric.optimalLow,
            high: config?.customRangeHigh ?? metric.optimalHigh,
            higherIsBetter: metric.higherIsBetter
        )
    }

    // 30-day history from DailySnapshot
    private var history: [(date: Date, value: Double)] {
        dailySnapshots
            .compactMap { snap -> (Date, Double)? in
                guard let v = snap.metricValues[metric.id] else { return nil }
                return (snap.date, v)
            }
            .sorted { $0.0 < $1.0 }
            .suffix(30)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xl) {
                    // Score ring + current value
                    headerSection

                    // 30-day trend chart
                    if history.count >= 2 {
                        trendChartSection
                    }

                    // Optimal range visualisation
                    rangeSection

                    // Longevity context
                    contextSection

                    // Evidence tier
                    tierSection
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.top, VSpacing.l)
                .padding(.bottom, VSpacing.huge)
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(VColor.accent)
                }
            }
        }
        .presentationBackground(VColor.backgroundPrimary)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: VSpacing.m) {
            if let score {
                ScoreRingView(
                    score: score,
                    color: status.color,
                    size: 140,
                    lineWidth: 14,
                    sublabel: status.label
                )
            } else {
                IncompleteRingView(size: 140, lineWidth: 14)
            }

            if let value = currentValue {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(value))
                        .font(VFont.scoreLargeFont)
                        .foregroundStyle(VColor.textPrimary)
                    Text(metric.unit)
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textSecondary)
                }
            }

            Text(metric.description)
                .font(VFont.captionFont)
                .foregroundStyle(VColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "30-Day Trend")

            Chart {
                // Optimal range band
                if let lo = config?.customRangeLow ?? metric.optimalLow,
                   let hi = config?.customRangeHigh ?? metric.optimalHigh {
                    RectangleMark(
                        xStart: .value("Start", history.first?.date ?? Date()),
                        xEnd: .value("End", history.last?.date ?? Date()),
                        yStart: .value("Low", lo),
                        yEnd: .value("High", hi)
                    )
                    .foregroundStyle(VColor.optimal.opacity(0.08))
                }

                // Data line
                ForEach(history, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.displayName, point.value)
                    )
                    .foregroundStyle(VColor.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.displayName, point.value)
                    )
                    .foregroundStyle(VColor.accent)
                    .symbolSize(30)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(VColor.borderSubtle)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(VColor.borderSubtle)
                    AxisValueLabel()
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .frame(height: 180)
            .padding(VSpacing.m)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Range Visualisation

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Optimal Range")

            VStack(spacing: VSpacing.s) {
                let low  = config?.customRangeLow  ?? metric.optimalLow
                let high = config?.customRangeHigh ?? metric.optimalHigh

                if let low, let high {
                    RangeBarView(
                        value: currentValue,
                        low: low,
                        high: high,
                        unit: metric.unit,
                        color: status.color
                    )
                } else if let low {
                    HStack {
                        Text("Target ≥ \(formatBound(low)) \(metric.unit)")
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(VColor.textSecondary)
                        Spacer()
                        if let value = currentValue {
                            Text(value >= low ? "In range" : "\(formatBound(low - value)) below target")
                                .font(VFont.captionFont)
                                .foregroundStyle(value >= low ? VColor.optimal : VColor.recoveryRed)
                        }
                    }
                    .padding(VSpacing.m)
                    .background(VColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                } else if let high {
                    HStack {
                        Text("Target ≤ \(formatBound(high)) \(metric.unit)")
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(VColor.textSecondary)
                        Spacer()
                        if let value = currentValue {
                            Text(value <= high ? "In range" : "\(formatBound(value - high)) above target")
                                .font(VFont.captionFont)
                                .foregroundStyle(value <= high ? VColor.optimal : VColor.recoveryRed)
                        }
                    }
                    .padding(VSpacing.m)
                    .background(VColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                } else {
                    Text("Scored relative to your personal baseline.")
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                        .padding(VSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                }
            }
        }
    }

    // MARK: - Longevity Context

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Why It Matters")

            Text(metric.longevityContext)
                .font(VFont.bodyMediumFont)
                .foregroundStyle(VColor.textSecondary)
                .lineSpacing(4)
                .padding(VSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Evidence Tier

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Evidence Level")

            HStack(spacing: VSpacing.m) {
                TierBadgeView(tier: metric.evidenceTier.rawValue)

                Text(tierDescription)
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(VSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Helpers

    private var tierDescription: String {
        switch metric.evidenceTier {
        case .tier1:
            return "Tier 1: Strongest longevity evidence. Weighted 3× in your Longevity Score."
        case .tier2:
            return "Tier 2: Good supporting evidence. Weighted 2× in your Longevity Score."
        case .tier3:
            return "Tier 3: Emerging or indirect evidence. Weighted 1× in your Longevity Score."
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch metric.id {
        case "vo2max":            return String(format: "%.1f", value)
        case "steps":             return "\(Int(value).formatted())"
        case "sleep_duration":    return String(format: "%.1f", value)
        case "sleep_efficiency", "deep_sleep_pct", "rem_sleep_pct", "awake_pct":
            return "\(Int(value.rounded()))%"
        case "hrv":               return "\(Int(value.rounded()))"
        case "zone2_minutes", "vigorous_minutes": return "\(Int(value.rounded()))"
        case "strength_sessions": return "\(Int(value.rounded()))"
        case "daylight_exposure": return "\(Int(value.rounded()))"
        case "wrist_temp":        return String(format: "%+.1f", value)
        default:                  return String(format: "%.0f", value)
        }
    }

    private func formatBound(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

// MARK: - Range Bar

private struct RangeBarView: View {
    let value: Double?
    let low: Double
    let high: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard let v = value else { return 0 }
        // Show bar from 0 to max(high * 1.3, value)
        let max = Swift.max(high * 1.3, value ?? high * 1.3)
        return Swift.max(0, Swift.min(1, v / max))
    }

    private var lowFraction: Double {
        let max = Swift.max(high * 1.3, value ?? high * 1.3)
        return low / max
    }

    private var highFraction: Double {
        let max = Swift.max(high * 1.3, value ?? high * 1.3)
        return high / max
    }

    var body: some View {
        VStack(spacing: VSpacing.s) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: VRadius.small)
                        .fill(VColor.borderSubtle)
                        .frame(height: 8)

                    // Optimal zone
                    RoundedRectangle(cornerRadius: VRadius.small)
                        .fill(VColor.optimal.opacity(0.25))
                        .frame(width: geo.size.width * (highFraction - lowFraction), height: 8)
                        .offset(x: geo.size.width * lowFraction)

                    // Current value marker
                    if let _ = value {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                            .offset(x: geo.size.width * progress - 8)
                            .shadow(color: color.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 16)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 16)

            HStack {
                Text(formatLabel(low))
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
                Spacer()
                Text(formatLabel(high))
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
        .padding(VSpacing.m)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
    }

    private func formatLabel(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v)) \(unit)" : String(format: "%.1f \(unit)", v)
    }
}

// MARK: - MetricStatus label helper

private extension MetricStatus {
    var label: String {
        switch self {
        case .optimal:    "Optimal"
        case .borderline: "Borderline"
        case .outOfRange: "Out of Range"
        case .noData:     "No Data"
        case .disabled:   "Disabled"
        }
    }
}

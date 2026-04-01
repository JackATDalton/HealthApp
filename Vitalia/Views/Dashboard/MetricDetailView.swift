import SwiftUI
import SwiftData
import Charts
import HealthKit

struct MetricDetailView: View {
    let metric: MetricDefinition
    let snapshot: [String: Double]
    let evalResult: MetricEvaluator.Result?
    let store: HKHealthStore

    @Environment(\.dismiss) private var dismiss
    @Query private var metricConfigs: [MetricConfig]
    @Query private var profiles: [UserProfile]

    @State private var selectedRange: MetricTimeRange = .month
    @State private var historyPoints: [HistoryPoint] = []
    @State private var isLoadingHistory = false

    private var config: MetricConfig? {
        metricConfigs.first { $0.metricID == metric.id }
    }

    private var currentValue: Double? { snapshot[metric.id] }
    private var userAge: Int { profiles.first?.ageYears ?? 35 }

    private var optimalLow: Double?  { config?.customRangeLow  ?? metric.optimalLow }
    private var optimalHigh: Double? { config?.customRangeHigh ?? metric.optimalHigh }

    private var status: MetricStatus {
        guard let v = currentValue else { return .noData }
        return evalResult?.status ?? MetricEvaluator.statusFromScore(
            MetricEvaluator.computeScore(value: v, low: optimalLow, high: optimalHigh,
                                         higherIsBetter: metric.higherIsBetter))
    }

    private var score: Double? {
        guard let v = currentValue else { return nil }
        return evalResult?.score ?? MetricEvaluator.computeScore(
            value: v, low: optimalLow, high: optimalHigh, higherIsBetter: metric.higherIsBetter)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xl) {
                    headerSection
                    todayBaselineSection
                    historySection
                    rangeSection
                    contextSection
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
            .task(id: selectedRange) { await loadHistory() }
        }
        .presentationBackground(VColor.backgroundPrimary)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: VSpacing.m) {
            if let score {
                ScoreRingView(score: score, color: status.color, size: 140,
                              lineWidth: 14, sublabel: status.label)
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

    // MARK: - Today vs 30-Day Baseline

    @ViewBuilder
    private var todayBaselineSection: some View {
        if let todayValue = snapshot["\(metric.id)_today"],
           let baselineValue = currentValue {
            VStack(alignment: .leading, spacing: VSpacing.m) {
                SectionHeaderView(title: "Today vs 30-Day Average")
                HStack(spacing: VSpacing.m) {
                    todayBaselineStat(label: "Tonight", value: todayValue, isTodayReading: true)
                    Divider().frame(height: 44)
                    todayBaselineStat(label: "30-Day Avg", value: baselineValue, isTodayReading: false)
                }
                .padding(VSpacing.l)
                .frame(maxWidth: .infinity)
                .background(VColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            }
        }
    }

    @ViewBuilder
    private func todayBaselineStat(label: String, value: Double, isTodayReading: Bool) -> some View {
        VStack(spacing: VSpacing.xs) {
            Text(label)
                .font(VFont.captionFont)
                .foregroundStyle(VColor.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatValue(value))
                    .font(VFont.bodyLargeFont.bold())
                    .foregroundStyle(isTodayReading ? VColor.textPrimary : VColor.accent)
                Text(metric.unit)
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History Chart

    private var historySection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "History")

            // Range picker
            HStack(spacing: VSpacing.xs) {
                ForEach(MetricTimeRange.allCases) { range in
                    Button(range.rawValue) { selectedRange = range }
                        .font(.system(size: VFont.bodySmall, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundStyle(selectedRange == range ? VColor.textInverse : VColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VSpacing.s)
                        .background(selectedRange == range ? VColor.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: VRadius.medium))
                }
            }
            .padding(4)
            .background(VColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.large))

            // Chart
            ZStack {
                if !historyPoints.isEmpty {
                    chartContent
                } else if isLoadingHistory {
                    Color.clear.frame(height: 180)
                } else {
                    Text("No data available for this period")
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(VColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                }

                if isLoadingHistory {
                    RoundedRectangle(cornerRadius: VRadius.xl)
                        .fill(VColor.backgroundSecondary)
                        .frame(height: 180)
                        .overlay(ProgressView().tint(VColor.accent))
                }
            }

            // Note for metrics whose history uses a different data source
            if let note = historyNote {
                Text(note)
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        let useBar = isBarChart

        Chart {
            // Optimal band or reference line (line charts only, where units match)
            if !useBar && showOptimalBand {
                if let lo = optimalLow, let hi = optimalHigh,
                   let first = historyPoints.first, let last = historyPoints.last {
                    RectangleMark(
                        xStart: .value("Start", first.date),
                        xEnd:   .value("End",   last.date),
                        yStart: .value("Low",   lo),
                        yEnd:   .value("High",  hi)
                    )
                    .foregroundStyle(VColor.optimal.opacity(0.08))
                } else if let lo = optimalLow, optimalHigh == nil, metric.higherIsBetter {
                    RuleMark(y: .value("Target", lo))
                        .foregroundStyle(VColor.optimal.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                } else if let hi = optimalHigh, optimalLow == nil, !metric.higherIsBetter {
                    RuleMark(y: .value("Target", hi))
                        .foregroundStyle(VColor.optimal.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                }
            }

            ForEach(historyPoints) { point in
                if useBar {
                    BarMark(
                        x: .value("Date",  point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(VColor.accent.opacity(0.8))
                    .cornerRadius(3)
                } else {
                    LineMark(
                        x: .value("Date",  point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(VColor.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date",  point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(VColor.accent)
                    .symbolSize(historyPoints.count > 30 ? 0 : 25)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedRange.xAxisComponent, count: selectedRange.xAxisStrideCount)) { _ in
                AxisGridLine().foregroundStyle(VColor.borderSubtle)
                AxisValueLabel(format: selectedRange.xAxisDateFormat)
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

    // MARK: - Optimal Range Visualisation

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Optimal Range")

            VStack(spacing: VSpacing.s) {
                if let low = optimalLow, let high = optimalHigh {
                    RangeBarView(value: currentValue, low: low, high: high,
                                 unit: metric.unit, color: status.color)
                } else if let low = optimalLow {
                    HStack {
                        Text("Target ≥ \(formatBound(low)) \(metric.unit)")
                            .font(VFont.bodyMediumFont).foregroundStyle(VColor.textSecondary)
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
                } else if let high = optimalHigh {
                    HStack {
                        Text("Target ≤ \(formatBound(high)) \(metric.unit)")
                            .font(VFont.bodyMediumFont).foregroundStyle(VColor.textSecondary)
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
                        .font(VFont.captionFont).foregroundStyle(VColor.textTertiary)
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
                .font(VFont.bodyMediumFont).foregroundStyle(VColor.textSecondary)
                .lineSpacing(4).padding(VSpacing.l)
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
                    .font(VFont.captionFont).foregroundStyle(VColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(VSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Data loading

    private func loadHistory() async {
        isLoadingHistory = true
        let fetcher = HealthKitHistoryFetcher(store: store)
        historyPoints = await fetcher.fetch(metricID: metric.id, range: selectedRange, userAge: userAge)
        isLoadingHistory = false
    }

    // MARK: - Computed helpers

    private var isBarChart: Bool {
        switch metric.id {
        case "steps", "zone2_minutes", "vigorous_minutes", "strength_sessions",
             "training_load", "mindful_minutes", "daylight_exposure":
            return true
        default: return false
        }
    }

    /// Don't overlay the optimal band when the history values use a different unit than the metric bounds
    private var showOptimalBand: Bool {
        switch metric.id {
        case "bmi", "body_weight_trend", "wrist_temp": return false
        default: return true
        }
    }

    private var historyNote: String? {
        switch metric.id {
        case "bmi":              return "Chart shows body weight (kg). BMI = weight ÷ height²."
        case "body_weight_trend": return "Chart shows body weight (kg)."
        case "wrist_temp":       return "Chart shows raw wrist temperature (°C)."
        default:                 return nil
        }
    }

    private var tierDescription: String {
        switch metric.evidenceTier {
        case .tier1: return "Tier 1: Strongest longevity evidence. Weighted 3× in your Longevity Score."
        case .tier2: return "Tier 2: Good supporting evidence. Weighted 2× in your Longevity Score."
        case .tier3: return "Tier 3: Emerging or indirect evidence. Weighted 1× in your Longevity Score."
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
        case "body_weight_trend": return String(format: "%.1f%%", value)
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
        let max = Swift.max(high * 1.3, v)
        return Swift.max(0, Swift.min(1, v / max))
    }
    private var lowFraction: Double  { low  / Swift.max(high * 1.3, value ?? high * 1.3) }
    private var highFraction: Double { high / Swift.max(high * 1.3, value ?? high * 1.3) }

    var body: some View {
        VStack(spacing: VSpacing.s) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VRadius.small)
                        .fill(VColor.borderSubtle).frame(height: 8)
                    RoundedRectangle(cornerRadius: VRadius.small)
                        .fill(VColor.optimal.opacity(0.25))
                        .frame(width: geo.size.width * (highFraction - lowFraction), height: 8)
                        .offset(x: geo.size.width * lowFraction)
                    if value != nil {
                        Circle().fill(color).frame(width: 16, height: 16)
                            .offset(x: geo.size.width * progress - 8)
                            .shadow(color: color.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 16).frame(maxWidth: .infinity)
            }
            .frame(height: 16)
            HStack {
                Text(formatLabel(low)).font(VFont.captionFont).foregroundStyle(VColor.textTertiary)
                Spacer()
                Text(formatLabel(high)).font(VFont.captionFont).foregroundStyle(VColor.textTertiary)
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

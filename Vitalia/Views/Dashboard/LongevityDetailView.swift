import SwiftUI
import SwiftData
import Charts
import HealthKit

struct LongevityDetailView: View {
    let result: LongevityScoreCalculator.Result
    let snapshot: [String: Double]
    let store: HKHealthStore

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailySnapshot.date) private var snapshots: [DailySnapshot]

    // Last 30 days with a longevity score
    private var trendData: [(date: Date, score: Double)] {
        snapshots
            .compactMap { snap -> (Date, Double)? in
                guard let s = snap.longevityScore else { return nil }
                return (snap.date, s)
            }
            .suffix(30)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xxl) {
                    scoreHeader
                    formulaCard
                    if trendData.count >= 2 {
                        trendChartSection
                    }
                    metricsSection
                }
                .padding(.bottom, VSpacing.huge)
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Longevity Score")
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

    // MARK: - Score Header

    private var scoreHeader: some View {
        ScoreRingView(
            score: result.score,
            color: scoreColor(result.score),
            size: 180,
            lineWidth: 18,
            sublabel: scoreLabel(result.score)
        )
        .padding(.top, VSpacing.xl)
    }

    // MARK: - Formula Card

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "How It's Calculated")

            VStack(spacing: 0) {
                formulaRow(
                    title: "Weighted Average",
                    subtitle: "Tier 1 = 3×, Tier 2 = 2×, Tier 3 = 1×",
                    value: result.weightedAverage,
                    showDivider: false
                )
            }
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
        .padding(.horizontal, VSpacing.l)
    }

    private func formulaRow(title: String, subtitle: String, value: Double, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: VSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textPrimary)
                    Text(subtitle)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.system(size: VFont.bodyMedium, weight: .semibold, design: .rounded))
                    .foregroundStyle(scoreColor(value))
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.vertical, VSpacing.m)

            if showDivider {
                Divider().background(VColor.borderSubtle).padding(.leading, VSpacing.l)
            }
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "30-Day Trend")

            Chart {
                // Colour bands
                RectangleMark(
                    xStart: .value("Start", trendData.first?.date ?? Date()),
                    xEnd:   .value("End",   trendData.last?.date  ?? Date()),
                    yStart: .value("Low",  75),
                    yEnd:   .value("High", 100)
                )
                .foregroundStyle(VColor.optimal.opacity(0.07))

                RectangleMark(
                    xStart: .value("Start", trendData.first?.date ?? Date()),
                    xEnd:   .value("End",   trendData.last?.date  ?? Date()),
                    yStart: .value("Low",  50),
                    yEnd:   .value("High", 75)
                )
                .foregroundStyle(VColor.borderline.opacity(0.05))

                ForEach(trendData, id: \.date) { point in
                    LineMark(
                        x: .value("Date",  point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(VColor.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date",  point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(scoreColor(point.score))
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(VColor.borderSubtle)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 50, 75, 100]) { _ in
                    AxisGridLine().foregroundStyle(VColor.borderSubtle)
                    AxisValueLabel().foregroundStyle(VColor.textTertiary)
                }
            }
            .frame(height: 200)
            .padding(VSpacing.m)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
        .padding(.horizontal, VSpacing.l)
    }

    // MARK: - Metrics Breakdown

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Metrics (worst → best)")
                .padding(.horizontal, VSpacing.l)

            VStack(spacing: 0) {
                ForEach(Array(result.metricScores.enumerated()), id: \.element.id) { idx, ms in
                    let metric = MetricDefinition.all.first { $0.id == ms.id }
                    NavigationLink {
                        if let metric {
                            MetricDetailView(
                                metric: metric,
                                snapshot: snapshot,
                                evalResult: nil,
                                store: store
                            )
                        }
                    } label: {
                        metricRow(ms: ms, definition: metric, showDivider: idx < result.metricScores.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            .padding(.horizontal, VSpacing.l)
        }
    }

    private func metricRow(ms: LongevityScoreCalculator.MetricScore, definition: MetricDefinition?, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: VSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: VSpacing.xs) {
                        Text(ms.displayName)
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(VColor.textPrimary)
                        TierBadgeView(tier: ms.tier.rawValue)
                    }
                    HStack(spacing: 4) {
                        Text(ms.status.label)
                            .font(VFont.captionFont)
                            .foregroundStyle(scoreColor(ms.score))
                        if let window = definition?.dataWindow {
                            Text("·")
                                .font(VFont.captionFont)
                                .foregroundStyle(VColor.textTertiary)
                            Text(window)
                                .font(VFont.captionFont)
                                .foregroundStyle(VColor.textTertiary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: VSpacing.s) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VColor.borderSubtle).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(scoreColor(ms.score))
                                .frame(width: geo.size.width * (ms.score / 100), height: 4)
                        }
                    }
                    .frame(width: 80, height: 4)

                    Text("\(Int(ms.score.rounded()))")
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(scoreColor(ms.score))
                        .frame(width: 28, alignment: .trailing)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VColor.textTertiary)
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.vertical, VSpacing.m)

            if showDivider {
                Divider().background(VColor.borderSubtle).padding(.leading, VSpacing.l)
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return VColor.optimal }
        if score >= 50 { return VColor.borderline }
        return VColor.outOfRange
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 80 { return "EXCELLENT" }
        if score >= 65 { return "GOOD" }
        if score >= 45 { return "NEEDS WORK" }
        return "CRITICAL"
    }
}

// MARK: - MetricStatus label (local extension if not already defined)

private extension MetricStatus {
    var label: String {
        switch self {
        case .optimal:    "Optimal"
        case .borderline: "Good"
        case .outOfRange: "Out of Range"
        case .noData:     "No Data"
        case .disabled:   "Disabled"
        }
    }
}

import SwiftUI
import SwiftData
import Charts

struct RecoveryDetailView: View {
    let result: RecoveryScoreResult?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailySnapshot.date) private var snapshots: [DailySnapshot]

    private var bandColor: Color {
        switch result?.band {
        case .recovered:      VColor.recoveryGreen
        case .moderate:       VColor.recoveryAmber
        case .fatigued:       VColor.recoveryOrange
        case .underRecovered: VColor.recoveryRed
        case nil:             VColor.textTertiary
        }
    }

    // Last 30 days with a recovery score
    private var trendData: [(date: Date, score: Double)] {
        snapshots
            .compactMap { snap -> (Date, Double)? in
                guard let s = snap.recoveryScore else { return nil }
                return (snap.date, s)
            }
            .suffix(30)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xxl) {
                    // Large score ring
                    if let result, !result.isIncomplete {
                        ScoreRingView(
                            score: result.score,
                            color: bandColor,
                            size: 180,
                            lineWidth: 18,
                            sublabel: result.band.rawValue.uppercased()
                        )
                        .padding(.top, VSpacing.xl)
                    } else {
                        IncompleteRingView(size: 180, lineWidth: 18)
                            .padding(.top, VSpacing.xl)
                    }

                    // Recommendation
                    if let result {
                        Text(result.band.recommendation)
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(VColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VSpacing.xl)
                    }

                    // 30-day trend chart
                    if trendData.count >= 2 {
                        trendChartSection
                    }

                    // Component breakdown
                    if let result {
                        breakdownSection(result: result)
                    }
                }
                .padding(.bottom, VSpacing.huge)
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Recovery Score")
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

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "30-Day Trend")

            Chart {
                // Band zones
                RectangleMark(
                    xStart: .value("Start", trendData.first?.date ?? Date()),
                    xEnd: .value("End", trendData.last?.date ?? Date()),
                    yStart: .value("Low", 85),
                    yEnd: .value("High", 100)
                )
                .foregroundStyle(VColor.recoveryGreen.opacity(0.07))

                RectangleMark(
                    xStart: .value("Start", trendData.first?.date ?? Date()),
                    xEnd: .value("End", trendData.last?.date ?? Date()),
                    yStart: .value("Low", 65),
                    yEnd: .value("High", 85)
                )
                .foregroundStyle(VColor.recoveryAmber.opacity(0.05))

                // Score line
                ForEach(trendData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(VColor.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
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
                AxisMarks(values: [0, 40, 65, 85, 100]) { value in
                    AxisGridLine().foregroundStyle(VColor.borderSubtle)
                    AxisValueLabel()
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .frame(height: 200)
            .padding(VSpacing.m)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            .padding(.horizontal, VSpacing.l)
        }
    }

    // MARK: - Component Breakdown

    private func breakdownSection(result: RecoveryScoreResult) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Component Breakdown")
                .padding(.horizontal, VSpacing.l)

            VStack(spacing: 0) {
                ForEach(Array(result.inputs.sortedInputs.enumerated()), id: \.element.name) { idx, input in
                    componentRow(
                        name: input.name,
                        score: input.score,
                        weight: input.weight,
                        showDivider: idx < result.inputs.sortedInputs.count - 1
                    )
                }
            }
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            .padding(.horizontal, VSpacing.l)
        }
    }

    private func componentRow(name: String, score: Double?, weight: Double, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: VSpacing.m) {
                // Component name + weight badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textPrimary)
                    Text("\(Int((weight * 100).rounded()))% weight")
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }

                Spacer()

                // Score bar + value
                if let score {
                    HStack(spacing: VSpacing.s) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VColor.borderSubtle)
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(scoreColor(score))
                                    .frame(width: geo.size.width * (score / 100), height: 4)
                            }
                        }
                        .frame(width: 80, height: 4)

                        Text("\(Int(score.rounded()))")
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(scoreColor(score))
                            .frame(width: 28, alignment: .trailing)
                    }
                } else {
                    Text("—")
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.vertical, VSpacing.m)

            if showDivider {
                Divider()
                    .background(VColor.borderSubtle)
                    .padding(.leading, VSpacing.l)
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score >= 85 { return VColor.recoveryGreen }
        if score >= 65 { return VColor.recoveryAmber }
        if score >= 40 { return VColor.recoveryOrange }
        return VColor.recoveryRed
    }
}

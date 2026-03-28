import SwiftUI

struct RecoveryScoreCard: View {
    let result: RecoveryScoreResult?
    var onTap: () -> Void = {}

    private var bandColor: Color {
        switch result?.band {
        case .recovered:      VColor.recoveryGreen
        case .moderate:       VColor.recoveryAmber
        case .fatigued:       VColor.recoveryOrange
        case .underRecovered: VColor.recoveryRed
        case nil:             VColor.textTertiary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Label("Recovery", systemImage: "bolt.heart.fill")
                            .font(VFont.bodySmallFont)
                            .foregroundStyle(VColor.textSecondary)
                            .labelStyle(.titleAndIcon)

                        if let result, !result.isIncomplete {
                            Text(result.band.rawValue)
                                .font(.system(size: VFont.bodySmall, weight: .semibold))
                                .foregroundStyle(bandColor)
                        } else if result?.isIncomplete == true {
                            Text("Incomplete")
                                .font(.system(size: VFont.bodySmall, weight: .semibold))
                                .foregroundStyle(VColor.textTertiary)
                        } else {
                            Text("Building baseline…")
                                .font(.system(size: VFont.bodySmall, weight: .regular))
                                .foregroundStyle(VColor.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VColor.textTertiary)
                }
                .padding(VSpacing.l)

                HStack(spacing: VSpacing.xxl) {
                    // Score ring
                    if let result, !result.isIncomplete {
                        ScoreRingView(
                            score: result.score,
                            color: bandColor,
                            size: 110,
                            lineWidth: 14
                        )
                    } else if result?.isIncomplete == true {
                        IncompleteRingView(size: 110, lineWidth: 14)
                    } else {
                        BaselineProgressView()
                    }

                    // Input breakdown — top 4 contributors
                    if let result, !result.isIncomplete {
                        VStack(alignment: .leading, spacing: VSpacing.s) {
                            ForEach(Array(result.inputs.sortedInputs.prefix(4)), id: \.name) { input in
                                InputBarRow(
                                    name: input.name,
                                    score: input.score ?? 0,
                                    accentColor: bandColor
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.bottom, VSpacing.l)

                // Recommendation strip
                if let result, !result.isIncomplete {
                    HStack {
                        Text(result.band.recommendation)
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textSecondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, VSpacing.l)
                    .padding(.vertical, VSpacing.m)
                    .background(bandColor.opacity(0.08))
                }
            }
        }
        .buttonStyle(.plain)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.xl)
                .strokeBorder(bandColor.opacity(result != nil ? 0.25 : 0.1), lineWidth: 1)
        )
    }
}

// MARK: - Input bar row

private struct InputBarRow: View {
    let name: String
    let score: Double
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
                Spacer()
                Text("\(Int(score.rounded()))")
                    .font(.system(size: VFont.caption, weight: .semibold, design: .rounded))
                    .foregroundStyle(VColor.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(VColor.backgroundTertiary).frame(height: 4)
                    Capsule()
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * (score / 100.0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return VColor.recoveryGreen }
        if score >= 50 { return VColor.recoveryAmber }
        return VColor.recoveryRed
    }
}

// MARK: - Baseline building state

private struct BaselineProgressView: View {
    var body: some View {
        VStack(spacing: VSpacing.m) {
            ZStack {
                Circle()
                    .stroke(VColor.backgroundTertiary, lineWidth: 14)
                    .frame(width: 110, height: 110)
                VStack(spacing: VSpacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(VColor.textTertiary)
                    Text("Building")
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }
            }
        }
    }
}

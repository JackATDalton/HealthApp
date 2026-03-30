import SwiftUI

struct LongevityScoreCard: View {
    let score: Double?
    var onTap: (() -> Void)? = nil

    private var scoreColor: Color {
        guard let score else { return VColor.textTertiary }
        if score >= 75 { return VColor.optimal }
        if score >= 50 { return VColor.borderline }
        return VColor.outOfRange
    }

    private var scoreLabel: String {
        guard let score else { return "—" }
        if score >= 80 { return "Excellent" }
        if score >= 65 { return "Good" }
        if score >= 45 { return "Needs Work" }
        return "Critical"
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: VSpacing.l) {
                // Score ring
                ScoreRingView(
                    score: score ?? 0,
                    color: scoreColor,
                    size: 72,
                    lineWidth: 9,
                    sublabel: nil
                )

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Label("Longevity Score", systemImage: "figure.run.circle.fill")
                        .font(VFont.bodySmallFont)
                        .foregroundStyle(VColor.textSecondary)
                        .labelStyle(.titleAndIcon)

                    if let score {
                        HStack(alignment: .firstTextBaseline, spacing: VSpacing.xs) {
                            Text("\(Int(score.rounded()))")
                                .font(.system(size: VFont.titleMedium, weight: .black, design: .rounded))
                                .foregroundStyle(VColor.textPrimary)
                                .contentTransition(.numericText())

                            Text("/ 100")
                                .font(VFont.bodySmallFont)
                                .foregroundStyle(VColor.textTertiary)
                        }

                        Text(scoreLabel)
                            .font(.system(size: VFont.bodySmall, weight: .semibold))
                            .foregroundStyle(scoreColor)
                    } else {
                        Text("Syncing…")
                            .font(VFont.bodyMediumFont)
                            .foregroundStyle(VColor.textTertiary)
                    }
                }

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VColor.textTertiary)
                }
            }
            .padding(VSpacing.l)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.xl)
                    .strokeBorder(scoreColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

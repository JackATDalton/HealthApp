import SwiftUI

struct ScoreRingView: View {
    let score: Double         // 0–100
    let color: Color
    let size: CGFloat
    var lineWidth: CGFloat = 12
    var showLabel: Bool = true
    var sublabel: String? = nil

    private var progress: Double { min(max(score / 100.0, 0), 1) }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(VColor.backgroundTertiary, lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Filled arc with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.7)]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

            // Score numeral
            if showLabel {
                VStack(spacing: 2) {
                    Text("\(Int(score.rounded()))")
                        .font(size >= 120 ? VFont.scoreHeroFont : VFont.scoreLargeFont)
                        .foregroundStyle(VColor.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: score)

                    if let sublabel {
                        Text(sublabel)
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }
                }
            }
        }
    }
}

// MARK: - Incomplete state overlay

struct IncompleteRingView: View {
    let size: CGFloat
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(VColor.backgroundTertiary, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    VColor.disabled,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [6, 4])
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(VColor.textTertiary)
                Text("Incomplete")
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
    }
}

import SwiftUI

enum MetricStatus {
    case optimal, borderline, outOfRange, disabled, noData

    var color: Color {
        switch self {
        case .optimal:    VColor.optimal
        case .borderline: VColor.borderline
        case .outOfRange: VColor.outOfRange
        case .disabled:   VColor.disabled
        case .noData:     VColor.textTertiary
        }
    }

    var faintColor: Color {
        switch self {
        case .optimal:    VColor.optimalFaint
        case .borderline: VColor.borderlineFaint
        case .outOfRange: VColor.outOfRangeFaint
        case .disabled:   VColor.backgroundTertiary
        case .noData:     VColor.backgroundTertiary
        }
    }
}

struct MetricCardView: View {
    let name: String
    let value: String
    let unit: String
    let tier: Int               // 1, 2, or 3
    let status: MetricStatus
    let progress: Double        // 0–1 fill of the bottom bar (how far through optimal range)
    var timeframe: String = ""
    var trendDirection: TrendDirection = .stable
    var isEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(name)
                        .font(VFont.bodySmallFont)
                        .foregroundStyle(isEnabled ? VColor.textSecondary : VColor.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !timeframe.isEmpty {
                        Text(timeframe)
                            .font(VFont.captionFont)
                            .foregroundStyle(isEnabled ? VColor.textTertiary : VColor.textTertiary.opacity(0.5))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value)
                            .font(VFont.metricValueFont)
                            .foregroundStyle(isEnabled ? VColor.textPrimary : VColor.textTertiary)
                            .contentTransition(.numericText())

                        Text(unit)
                            .font(VFont.metricUnitFont)
                            .foregroundStyle(isEnabled ? VColor.textTertiary : VColor.textTertiary.opacity(0.6))
                    }
                }

                Spacer(minLength: VSpacing.xs)

                VStack(alignment: .trailing, spacing: VSpacing.xs) {
                    TierBadgeView(tier: tier, isEnabled: isEnabled)
                    TrendArrowView(direction: trendDirection, isEnabled: isEnabled)
                }
            }
            .padding(VSpacing.m)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(VColor.borderSubtle)
                        .frame(height: 3)

                    Rectangle()
                        .fill(isEnabled ? status.color : VColor.disabled)
                        .frame(width: geo.size.width * (isEnabled ? min(max(progress, 0), 1) : 0), height: 3)
                        .animation(.spring(response: 0.6), value: progress)
                }
            }
            .frame(height: 3)
        }
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.xl)
                .strokeBorder(isEnabled ? status.color.opacity(0.2) : VColor.borderSubtle, lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Trend arrow

enum TrendDirection {
    case up, down, stable

    var systemImage: String {
        switch self {
        case .up:     "arrow.up.right"
        case .down:   "arrow.down.right"
        case .stable: "arrow.right"
        }
    }
}

struct TrendArrowView: View {
    let direction: TrendDirection
    var isEnabled: Bool = true

    var color: Color {
        guard isEnabled else { return VColor.textTertiary }
        switch direction {
        case .up:     return VColor.optimal
        case .down:   return VColor.outOfRange
        case .stable: return VColor.textTertiary
        }
    }

    var body: some View {
        Image(systemName: direction.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
    }
}

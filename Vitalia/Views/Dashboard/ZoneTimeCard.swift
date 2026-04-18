import SwiftUI

struct ZoneTimeCard: View {
    let zone2Minutes: Double?
    let vigorousMinutes: Double?

    private static let zone2Target:    Double = 180
    private static let vigorousTarget: Double = 75

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            Label("Weekly Zone Time", systemImage: "waveform.path.ecg")
                .font(VFont.bodySmallFont)
                .foregroundStyle(VColor.textSecondary)
                .labelStyle(.titleAndIcon)

            VStack(spacing: VSpacing.m) {
                ZoneRow(
                    label: "Zone 2",
                    subtitle: "Aerobic base",
                    minutes: zone2Minutes,
                    target: Self.zone2Target
                )

                Divider().background(VColor.textTertiary.opacity(0.15))

                ZoneRow(
                    label: "Vigorous",
                    subtitle: "Zone 3–5",
                    minutes: vigorousMinutes,
                    target: Self.vigorousTarget
                )
            }
        }
        .padding(VSpacing.l)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
    }
}

// MARK: - Zone row

private struct ZoneRow: View {
    let label: String
    let subtitle: String
    let minutes: Double?
    let target: Double

    private var progress: Double {
        guard let m = minutes else { return 0 }
        return min(1.0, m / target)
    }

    private var barColor: Color {
        if progress >= 0.90 { return VColor.excellent }
        if progress >= 0.75 { return VColor.optimal }
        if progress >= 0.25 { return VColor.borderline }
        return VColor.outOfRange
    }

    private var valueText: String {
        guard let m = minutes else { return "—" }
        return "\(Int(m.rounded())) min"
    }

    private var targetText: String {
        "/ \(Int(target)) min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: VFont.bodyMedium, weight: .semibold))
                        .foregroundStyle(VColor.textPrimary)
                    Text(subtitle)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(valueText)
                        .font(.system(size: VFont.bodyMedium, weight: .bold, design: .rounded))
                        .foregroundStyle(minutes != nil ? barColor : VColor.textTertiary)
                    Text(targetText)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(barColor.opacity(0.12))
                        .frame(height: 5)

                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 5)
        }
    }
}

import SwiftUI

struct FocusMetricCard: View {
    let metricID: String?
    var onTap: (() -> Void)? = nil

    private var definition: MetricDefinition? {
        guard let id = metricID else { return nil }
        return MetricDefinition.definition(for: id)
    }

    var body: some View {
        if let def = definition {
            Button { onTap?() } label: {
            HStack(spacing: VSpacing.m) {
                // Accent left bar
                RoundedRectangle(cornerRadius: VRadius.full)
                    .fill(VColor.accent)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    HStack {
                        Label("Current Focus", systemImage: "scope")
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .labelStyle(.titleAndIcon)
                        Spacer()
                        TierBadgeView(tier: def.evidenceTier.rawValue)
                    }

                    Text(def.displayName)
                        .font(VFont.titleSmallFont)
                        .foregroundStyle(VColor.textPrimary)

                    Text(def.longevityContext)
                        .font(VFont.bodySmallFont)
                        .foregroundStyle(VColor.textSecondary)
                        .lineLimit(2)
                }

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VColor.accent.opacity(0.6))
                }
            }
            .padding(VSpacing.l)
            .background(VColor.accentFaint)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.xl)
                    .strokeBorder(VColor.accent.opacity(0.25), lineWidth: 1)
            )
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
        }
    }
}

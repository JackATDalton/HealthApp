import SwiftUI
import SwiftData

struct OnboardingMetricsView: View {
    @Binding var disabledMetricIDs: Set<String>
    let onComplete: () -> Void

    private let categories = MetricCategory.allCases

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: VSpacing.xs) {
                Text("Your Metrics")
                    .font(VFont.titleLargeFont)
                    .foregroundStyle(VColor.textPrimary)
                Text("Disable any metrics you don't want tracked.\nYou can change this anytime in Settings.")
                    .font(VFont.bodyMediumFont)
                    .foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, VSpacing.huge)
            .padding(.horizontal, VSpacing.xl)

            List {
                ForEach(categories, id: \.self) { category in
                    let metrics = MetricDefinition.all.filter { $0.category == category }
                    Section {
                        ForEach(metrics) { metric in
                            metricRow(metric)
                        }
                    } header: {
                        Text(category.rawValue.uppercased())
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textTertiary)
                            .tracking(0.6)
                    }
                    .listRowBackground(VColor.backgroundSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            Button(action: onComplete) {
                Text("Get Started")
                    .font(.system(size: VFont.bodyLarge, weight: .semibold))
                    .foregroundStyle(VColor.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VSpacing.l)
                    .background(VColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.bottom, VSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColor.backgroundPrimary.ignoresSafeArea())
    }

    private func metricRow(_ metric: MetricDefinition) -> some View {
        let isEnabled = !disabledMetricIDs.contains(metric.id)

        return HStack(spacing: VSpacing.m) {
            TierBadgeView(tier: metric.evidenceTier.rawValue, isEnabled: isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                    .font(.system(size: VFont.bodyMedium, weight: isEnabled ? .medium : .regular))
                    .foregroundStyle(isEnabled ? VColor.textPrimary : VColor.textTertiary)
                Text(metric.unit)
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    if enabled { disabledMetricIDs.remove(metric.id) }
                    else { disabledMetricIDs.insert(metric.id) }
                }
            ))
            .tint(VColor.accent)
            .labelsHidden()
        }
        .opacity(isEnabled ? 1 : 0.55)
    }
}

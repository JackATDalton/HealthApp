import SwiftUI
import SwiftData

struct MetricsSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var configs: [MetricConfig]

    private let categories = MetricCategory.allCases

    var body: some View {
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
        .background(VColor.backgroundPrimary)
        .navigationTitle("Metrics")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func metricRow(_ metric: MetricDefinition) -> some View {
        let isEnabled = config(for: metric.id)?.isEnabled ?? true

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
                set: { enabled in setEnabled(enabled, for: metric.id) }
            ))
            .tint(VColor.accent)
            .labelsHidden()
        }
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func config(for metricID: String) -> MetricConfig? {
        configs.first { $0.metricID == metricID }
    }

    private func setEnabled(_ enabled: Bool, for metricID: String) {
        if let existing = config(for: metricID) {
            existing.isEnabled = enabled
            existing.updatedAt = Date()
        } else {
            // No config yet — insert one (default was implicitly true, so only needed when disabling)
            let cfg = MetricConfig(metricID: metricID, isEnabled: enabled)
            context.insert(cfg)
        }
    }
}

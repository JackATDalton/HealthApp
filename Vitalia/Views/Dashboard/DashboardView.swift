import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Query private var metricConfigs: [MetricConfig]
    @State private var showRecoveryDetail = false
    @State private var syncPulse = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: VSpacing.xl) {
                        // Recovery + Longevity scores
                        RecoveryScoreCard(result: appState.recoveryResult) {
                            showRecoveryDetail = true
                        }

                        LongevityScoreCard(score: appState.longevityScore)

                        // Focus metric (from last plan)
                        if let _ = appState.focusMetricID {
                            FocusMetricCard(metricID: appState.focusMetricID)
                        }

                        // Re-plan nudge
                        if appState.showRePlanNudge {
                            RePlanNudgeBanner {
                                // navigate to plan tab
                            } onDismiss: {
                                withAnimation { appState.showRePlanNudge = false }
                            }
                        }

                        // Metric grid
                        MetricGridView(
                            snapshots: appState.metricSnapshot.isEmpty
                                ? MetricGridView.mockSnapshots   // show mock until first sync
                                : appState.metricSnapshot,
                            configs: metricConfigs
                        )
                    }
                    .padding(.horizontal, VSpacing.l)
                    .padding(.top, VSpacing.m)
                    .padding(.bottom, 100)
                }

                // Sync status footer
                syncFooter
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Vitalia")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    syncButton
                }
            }
            .sheet(isPresented: $showRecoveryDetail) {
                RecoveryDetailPlaceholderView(result: appState.recoveryResult)
            }
        }
        .task {
            // Sync is triggered by RootView on launch; this just ensures
            // any manual foreground-returns re-use the already-populated state.
        }
    }

    private var syncButton: some View {
        Button {
            withAnimation { syncPulse.toggle() }
            Task { await appState.sync() }
        } label: {
            Image(systemName: appState.isSyncing ? "arrow.clockwise" : "arrow.clockwise")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(appState.isSyncing ? VColor.accent : VColor.textSecondary)
                .rotationEffect(.degrees(syncPulse ? 360 : 0))
                .animation(appState.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .spring(), value: syncPulse)
        }
    }

    private var syncFooter: some View {
        HStack {
            if let date = appState.lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(VColor.optimal)
                Text("Synced \(date.formatted(.relative(presentation: .named)))")
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpacing.s)
        .background(.ultraThinMaterial.opacity(0.8))
    }
}

// MARK: - Recovery detail placeholder (full view in Phase 3)

private struct RecoveryDetailPlaceholderView: View {
    let result: RecoveryScoreResult?
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xxl) {
                    // Large ring
                    if let result, !result.isIncomplete {
                        ScoreRingView(
                            score: result.score,
                            color: bandColor,
                            size: 180,
                            lineWidth: 18,
                            sublabel: result.band.rawValue.uppercased()
                        )
                        .padding(.top, VSpacing.xl)
                    }

                    // Input breakdown
                    if let result {
                        VStack(spacing: 0) {
                            ForEach(Array(result.inputs.sortedInputs.enumerated()), id: \.element.name) { idx, input in
                                StatRowView(
                                    label: input.name,
                                    value: input.score.map { "\(Int($0.rounded()))/100" } ?? "—",
                                    valueColor: scoreColor(input.score ?? 0),
                                    showDivider: idx < result.inputs.sortedInputs.count - 1
                                )
                                .padding(.horizontal, VSpacing.l)
                            }
                        }
                        .background(VColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                        .padding(.horizontal, VSpacing.l)
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

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return VColor.recoveryGreen }
        if score >= 50 { return VColor.recoveryAmber }
        return VColor.recoveryRed
    }
}

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Query private var metricConfigs: [MetricConfig]
    @State private var showRecoveryDetail = false
    @State private var showLongevityDetail = false
    @State private var selectedMetric: MetricDefinition? = nil
    @State private var syncPulse = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xl) {
                    // Recovery + Longevity scores
                    RecoveryScoreCard(result: appState.recoveryResult) {
                        showRecoveryDetail = true
                    }

                    LongevityScoreCard(score: appState.longevityScore) {
                        showLongevityDetail = true
                    }

                    // Zone time card
                    if appState.metricSnapshot["zone2_minutes"] != nil || appState.metricSnapshot["vigorous_minutes"] != nil {
                        ZoneTimeCard(
                            zone2Minutes: appState.metricSnapshot["zone2_minutes"],
                            vigorousMinutes: appState.metricSnapshot["vigorous_minutes"]
                        )
                    }

                    // Focus metric (from last plan)
                    if let _ = appState.focusMetricID {
                        FocusMetricCard(metricID: appState.focusMetricID) {
                            if let id = appState.focusMetricID,
                               let def = MetricDefinition.definition(for: id) {
                                selectedMetric = def
                            }
                        }
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
                            ? MetricGridView.mockSnapshots
                            : appState.metricSnapshot,
                        configs: metricConfigs,
                        evalResults: appState.metricEvalResults
                    ) { metric in
                        selectedMetric = metric
                    }
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.top, VSpacing.m)
                .padding(.bottom, 60)
            }
            .overlay(alignment: .bottom) {
                syncFooter
                    .allowsHitTesting(false)
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
                RecoveryDetailView(result: appState.recoveryResult, snapshot: appState.metricSnapshot)
            }
            .sheet(isPresented: $showLongevityDetail) {
                if let result = appState.longevityResult {
                    LongevityDetailView(
                        result: result,
                        snapshot: appState.metricSnapshot,
                        store: appState.store
                    )
                }
            }
            .sheet(item: $selectedMetric) { metric in
                MetricDetailView(
                    metric: metric,
                    snapshot: appState.metricSnapshot,
                    evalResult: appState.metricEvalResults[metric.id],
                    store: appState.store
                )
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


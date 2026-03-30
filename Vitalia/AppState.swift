import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class AppState {
    // MARK: - Onboarding
    var isOnboardingComplete: Bool = false

    // MARK: - Sync state
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var syncError: String?

    // MARK: - Scores (populated after sync)
    var recoveryResult: RecoveryScoreResult? = nil
    var longevityScore: Double? = nil
    var focusMetricID: String? = nil      // set from last LongevityPlan

    // MARK: - Live metric snapshot (keyed by MetricDefinition.id)
    var metricSnapshot: [String: Double] = [:]

    // MARK: - Re-plan nudge
    var showRePlanNudge: Bool = false
    private var snapshotAtLastPlan: [String: Double] = [:]

    // MARK: - Shared HealthKit store (one instance for the app lifetime)
    private let hkPermissions = HealthKitPermissionsManager()

    // MARK: - Sync

    func sync(modelContext: ModelContext? = nil) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // Determine user age (needed for zone calculations)
        let age = resolveUserAge(from: modelContext)

        // Fetch all metrics
        let collector = HealthKitMetricsCollector(store: hkPermissions.store)
        let snapshot  = await collector.collect(userAge: age)
        metricSnapshot = snapshot

        // Detect re-plan nudge
        if !snapshotAtLastPlan.isEmpty {
            showRePlanNudge = shouldNudgeRePlan(current: snapshot, previous: snapshotAtLastPlan)
        }

        // Phase 3 will wire in full score calculators here.
        // For now: expose raw snapshot to the dashboard.
    }

    // MARK: - Called after a plan is saved

    func onPlanSaved(plan: LongevityPlan) {
        focusMetricID       = plan.focusMetricID
        snapshotAtLastPlan  = metricSnapshot
        showRePlanNudge     = false
    }

    // MARK: - Private helpers

    private func resolveUserAge(from context: ModelContext?) -> Int {
        // Try to read from SwiftData profile; fall back to 35 as a neutral default
        guard let context else { return 35 }
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? context.fetch(descriptor)) ?? []
        return profiles.first?.ageYears ?? 35
    }

    private func shouldNudgeRePlan(current: [String: Double], previous: [String: Double]) -> Bool {
        // Nudge if 3+ metrics have shifted by more than 10% of their optimal range
        var changedCount = 0
        for def in MetricDefinition.all {
            guard let curr = current[def.id], let prev = previous[def.id] else { continue }
            let rangeSpan: Double
            if let lo = def.optimalLow, let hi = def.optimalHigh {
                rangeSpan = hi - lo
            } else if let lo = def.optimalLow {
                rangeSpan = lo * 0.5
            } else if let hi = def.optimalHigh {
                rangeSpan = hi * 0.5
            } else {
                continue
            }
            guard rangeSpan > 0 else { continue }
            let shift = abs(curr - prev) / rangeSpan
            if shift > 0.10 { changedCount += 1 }
        }
        return changedCount >= 3
    }
}

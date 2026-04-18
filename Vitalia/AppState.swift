import SwiftUI
import SwiftData
import Observation
import HealthKit
import WidgetKit

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
    var longevityResult: LongevityScoreCalculator.Result? = nil
    var focusMetricID: String? = nil      // set from last LongevityPlan

    var longevityScore: Double? { longevityResult?.score }

    // MARK: - Live metric snapshot (keyed by MetricDefinition.id)
    var metricSnapshot: [String: Double] = [:]

    // MARK: - Recent workouts (populated after sync)
    var recentWorkouts: [HealthKitWorkoutAnalyser.RecentWorkout] = []

    // Per-metric evaluated scores (for dashboard cards)
    var metricEvalResults: [String: MetricEvaluator.Result] = [:]

    // MARK: - Re-plan nudge
    var showRePlanNudge: Bool = false
    private var snapshotAtLastPlan: [String: Double] = [:]

    // MARK: - Shared HealthKit store
    private let hkPermissions = HealthKitPermissionsManager()
    var store: HKHealthStore { hkPermissions.store }

    // MARK: - Sync

    func sync(modelContext: ModelContext? = nil) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        let age = resolveUserAge(from: modelContext)

        // 1. Collect all HealthKit metrics (concurrent queries)
        let collector = HealthKitMetricsCollector(store: hkPermissions.store)
        let collected = await collector.collect(userAge: age)
        let snapshot  = collected.snapshot
        metricSnapshot  = snapshot
        recentWorkouts  = collected.recentWorkouts

        // 2. Calculate Recovery Score
        let recoveryInputs = RecoveryScoreCalculator.inputs(from: snapshot)
        let recovery       = RecoveryScoreCalculator.calculate(inputs: recoveryInputs)
        recoveryResult     = recovery

        // 3. Evaluate each metric (for dashboard card colours + longevity score)
        let configs = (try? modelContext?.fetch(FetchDescriptor<MetricConfig>())) ?? []
        let configMap = Dictionary(uniqueKeysWithValues: configs.map { ($0.metricID, $0) })

        var evalResults: [String: MetricEvaluator.Result] = [:]
        for def in MetricDefinition.all {
            guard let value = snapshot[def.id] else { continue }
            let config = configMap[def.id]
            evalResults[def.id] = MetricEvaluator.evaluate(
                value,
                definition: def,
                customLow:  config?.customRangeLow,
                customHigh: config?.customRangeHigh
            )
        }
        metricEvalResults = evalResults

        // 4. Calculate Longevity Score
        let longevity = LongevityScoreCalculator.calculate(snapshot: snapshot, configs: configs)
        longevityResult = longevity

        // 5. Save DailySnapshot to SwiftData
        if let context = modelContext {
            saveDailySnapshot(
                snapshot: snapshot,
                recovery: recovery,
                longevityScore: longevity.score,
                context: context
            )
        }

        // 6. Re-plan nudge
        if !snapshotAtLastPlan.isEmpty {
            showRePlanNudge = shouldNudgeRePlan(current: snapshot, previous: snapshotAtLastPlan)
        }

        // 7. Push scores to widget
        writeWidgetData(plan: nil)
    }

    // MARK: - Called after a plan is saved

    func onPlanSaved(plan: LongevityPlan) {
        focusMetricID      = plan.focusMetricID
        snapshotAtLastPlan = metricSnapshot
        showRePlanNudge    = false
        writeWidgetData(plan: plan)
    }

    // MARK: - Private helpers

    private func resolveUserAge(from context: ModelContext?) -> Int {
        guard let context else { return 35 }
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        return profiles.first?.ageYears ?? 35
    }

    private func saveDailySnapshot(
        snapshot: [String: Double],
        recovery: RecoveryScoreResult,
        longevityScore: Double,
        context: ModelContext
    ) {
        let today = Calendar.current.startOfDay(for: Date())

        // Upsert: update existing snapshot for today if it exists
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate { $0.date == today }
        )
        let existing = (try? context.fetch(descriptor))?.first

        let ds = existing ?? {
            let new = DailySnapshot(date: today)
            context.insert(new)
            return new
        }()

        ds.metricValues = snapshot
        ds.recoveryScore = recovery.isIncomplete ? nil : recovery.score
        ds.recoveryBand  = recovery.band
        ds.recoveryIncompleteReasons = recovery.incompleteReasons
        ds.longevityScore = longevityScore
        ds.syncedAt = Date()

        // Encode recovery inputs
        if let data = try? JSONEncoder().encode(recovery.inputs) {
            ds.recoveryInputsData = data
        }

        try? context.save()
    }

    // MARK: - Widget data

    private func writeWidgetData(plan: LongevityPlan?) {
        guard let defaults = UserDefaults(suiteName: "group.com.jackdalton.Vitalia") else { return }

        if let recovery = recoveryResult, !recovery.isIncomplete {
            defaults.set(recovery.score,        forKey: "widget.recoveryScore")
            defaults.set(recovery.band.rawValue, forKey: "widget.recoveryBand")
            defaults.set(true,                   forKey: "widget.recoveryValid")
        } else {
            defaults.set(false, forKey: "widget.recoveryValid")
        }

        if let longevity = longevityResult {
            defaults.set(longevity.score, forKey: "widget.longevityScore")
            defaults.set(true,             forKey: "widget.longevityValid")
        } else {
            defaults.set(false, forKey: "widget.longevityValid")
        }

        if let plan {
            let (_, days) = WorkoutDay.parse(from: plan.fullText)
            if let today = todayWorkoutDay(from: days) {
                defaults.set(today.dayName,          forKey: "widget.workoutDayName")
                defaults.set(today.isRest,            forKey: "widget.workoutIsRest")
                defaults.set(today.type     ?? "",    forKey: "widget.workoutType")
                defaults.set(today.duration ?? "",    forKey: "widget.workoutDuration")
                defaults.set(today.zones    ?? "",    forKey: "widget.workoutZones")
                defaults.set(today.notes    ?? "",    forKey: "widget.workoutNotes")
            }
        }

        defaults.set(Date().timeIntervalSince1970, forKey: "widget.lastUpdated")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func todayWorkoutDay(from days: [WorkoutDay]) -> WorkoutDay? {
        let weekday  = Calendar.current.component(.weekday, from: Date())
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayName = dayNames[weekday - 1]
        return days.first {
            $0.dayName.lowercased().contains(todayName.lowercased()) ||
            todayName.lowercased().contains(String($0.dayName.lowercased().prefix(3)))
        }
    }

    private func shouldNudgeRePlan(current: [String: Double], previous: [String: Double]) -> Bool {
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
            if abs(curr - prev) / rangeSpan > 0.10 { changedCount += 1 }
        }
        return changedCount >= 3
    }
}

import HealthKit

/// Reads 30-day passive progress signals sent to Claude in the longevity plan prompt.
@MainActor
final class HealthKitPassiveReader {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct PassiveContext {
        var avgSleepHours30Day:    Double?
        var avgSleepEfficiency30Day: Double?
        var zone2MinutesWeek:      Double?
        var vigorousMinutesWeek:   Double?
        var strengthSessionsWeek:  Double?
        var avgDailySteps30Day:    Double?
        var avgActiveEnergy30Day:  Double?
    }

    func read(userAge: Int) async -> PassiveContext {
        let sleepAnalyser   = HealthKitSleepAnalyser(store: store)
        let workoutAnalyser = HealthKitWorkoutAnalyser(store: store)

        async let sleepResult   = sleepAnalyser.fetchSleepResult()
        async let workoutResult = workoutAnalyser.fetchWorkoutResult(userAge: userAge)
        async let steps30Day    = fetchDailyAverage(.stepCount,          unit: .count(),       daysBack: 30)
        async let energy30Day   = fetchDailyAverage(.activeEnergyBurned, unit: .kilocalorie(), daysBack: 30)

        let sleep   = await sleepResult
        let workout = await workoutResult
        let steps   = await steps30Day
        let energy  = await energy30Day

        let avgSleepHrs = sleep.recent7Days.isEmpty ? nil :
            sleep.recent7Days.reduce(0.0) { $0 + $1.durationHours } / Double(sleep.recent7Days.count)
        let avgEff = sleep.recent7Days.isEmpty ? nil :
            sleep.recent7Days.reduce(0.0) { $0 + $1.efficiency } / Double(sleep.recent7Days.count) * 100

        return PassiveContext(
            avgSleepHours30Day:      avgSleepHrs,
            avgSleepEfficiency30Day: avgEff,
            zone2MinutesWeek:        workout.zone2MinutesWeekly,
            vigorousMinutesWeek:     workout.vigorousMinutesWeekly,
            strengthSessionsWeek:    workout.strengthSessionsWeekly,
            avgDailySteps30Day:      steps,
            avgActiveEnergy30Day:    energy
        )
    }

    private func fetchDailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                guard let total = stats?.sumQuantity()?.doubleValue(for: unit) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: total / Double(daysBack))
            }
            store.execute(query)
        }
    }
}

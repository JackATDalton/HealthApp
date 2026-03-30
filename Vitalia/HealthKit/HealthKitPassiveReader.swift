import HealthKit

/// Reads the 7-day passive progress signals sent to Claude in the longevity plan prompt.
@MainActor
final class HealthKitPassiveReader {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct PassiveContext {
        var avgSleepHours7Day:    Double?
        var avgSleepEfficiency7Day: Double?
        var zone2MinutesWeek:     Double?
        var vigorousMinutesWeek:  Double?
        var strengthSessionsWeek: Int?
        var avgDailySteps7Day:    Double?
        var avgActiveEnergy7Day:  Double?
    }

    func read(userAge: Int) async -> PassiveContext {
        let sleepAnalyser   = HealthKitSleepAnalyser(store: store)
        let workoutAnalyser = HealthKitWorkoutAnalyser(store: store)

        async let sleepResult   = sleepAnalyser.fetchSleepResult()
        async let workoutResult = workoutAnalyser.fetchWorkoutResult(userAge: userAge)
        async let steps7Day     = fetchWeeklyDailyAverage(.stepCount, unit: .count())
        async let energy7Day    = fetchWeeklyDailyAverage(.activeEnergyBurned, unit: .kilocalorie())

        let sleep   = await sleepResult
        let workout = await workoutResult
        let steps   = await steps7Day
        let energy  = await energy7Day

        let avgSleepHrs = sleep.recent7Days.isEmpty ? nil :
            sleep.recent7Days.reduce(0.0) { $0 + $1.durationHours } / Double(sleep.recent7Days.count)
        let avgEff = sleep.recent7Days.isEmpty ? nil :
            sleep.recent7Days.reduce(0.0) { $0 + $1.efficiency } / Double(sleep.recent7Days.count) * 100

        return PassiveContext(
            avgSleepHours7Day:      avgSleepHrs,
            avgSleepEfficiency7Day: avgEff,
            zone2MinutesWeek:       workout.zone2MinutesWeekly,
            vigorousMinutesWeek:    workout.vigorousMinutesWeekly,
            strengthSessionsWeek:   workout.strengthSessionsWeekly,
            avgDailySteps7Day:      steps,
            avgActiveEnergy7Day:    energy
        )
    }

    private func fetchWeeklyDailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
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
                continuation.resume(returning: total / 7.0)
            }
            store.execute(query)
        }
    }
}

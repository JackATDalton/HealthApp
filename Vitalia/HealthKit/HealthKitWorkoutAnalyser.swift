import HealthKit

/// Derives Zone 2 minutes, vigorous minutes, strength sessions, and 7-day training load
/// from Apple Watch workout data and associated heart rate samples.
@MainActor
final class HealthKitWorkoutAnalyser {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct WorkoutResult {
        let zone2MinutesWeekly:    Double
        let vigorousMinutesWeekly: Double
        let strengthSessionsWeekly: Int
        let trainingLoad7Day:      Double      // arbitrary units: sum(avgHRPct * durationMin)
    }

    // MARK: - Fetch

    func fetchWorkoutResult(userAge: Int) async -> WorkoutResult {
        let workouts = await fetchWorkouts(daysBack: 7)

        let maxHR = Double(220 - userAge)
        let zone2Low  = maxHR * 0.60
        let zone2High = maxHR * 0.70
        let vigorousThreshold = maxHR * 0.80

        var zone2Mins:    Double = 0
        var vigorousMins: Double = 0
        var strengthCount = 0
        var trainingLoad:  Double = 0

        for workout in workouts {
            if isStrengthWorkout(workout) {
                strengthCount += 1
                // Still count HR-based load for strength if HR data available
            }

            // Fetch HR samples scoped to this workout
            let hrSamples = await fetchHRSamples(for: workout)

            if hrSamples.isEmpty {
                // Fall back: classify workout by type only
                if !isStrengthWorkout(workout) {
                    // Assume zone 2 for unknown cardio
                    zone2Mins += workout.duration / 60
                }
                continue
            }

            // Calculate time in each zone from 5-second-ish HR samples
            var z2Secs:  Double = 0
            var vigSecs: Double = 0
            var sumHR:   Double = 0
            var count    = 0

            for (index, sample) in hrSamples.enumerated() {
                let hr = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                sumHR += hr
                count += 1

                // Duration represented by this sample = gap to next sample (or 5s default)
                let nextDate: Date
                if index + 1 < hrSamples.count {
                    nextDate = hrSamples[index + 1].startDate
                } else {
                    nextDate = sample.startDate.addingTimeInterval(5)
                }
                let sampleDuration = nextDate.timeIntervalSince(sample.startDate)
                guard sampleDuration > 0, sampleDuration < 120 else { continue }

                if hr >= zone2Low && hr <= zone2High {
                    z2Secs  += sampleDuration
                } else if hr > vigorousThreshold {
                    vigSecs += sampleDuration
                }
            }

            zone2Mins    += z2Secs  / 60
            vigorousMins += vigSecs / 60

            // Training load: avgHRPct × durationMin
            if count > 0 {
                let avgHRPct = (sumHR / Double(count)) / maxHR
                trainingLoad += avgHRPct * (workout.duration / 60)
            }
        }

        return WorkoutResult(
            zone2MinutesWeekly:     zone2Mins,
            vigorousMinutesWeekly:  vigorousMins,
            strengthSessionsWeekly: strengthCount,
            trainingLoad7Day:       trainingLoad
        )
    }

    // MARK: - Private

    private func fetchWorkouts(daysBack: Int) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchHRSamples(for workout: HKWorkout) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKQuantityType(.heartRate),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func isStrengthWorkout(_ workout: HKWorkout) -> Bool {
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining,
             .crossTraining,
             .wrestling,
             .gymnastics:
            return true
        default:
            return false
        }
    }
}

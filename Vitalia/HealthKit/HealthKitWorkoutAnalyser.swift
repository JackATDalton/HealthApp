import HealthKit

/// Derives Zone 2 minutes, vigorous minutes, strength sessions, and training load
/// from the last 30 days of Apple Watch workout data, expressed as weekly averages.
@MainActor
final class HealthKitWorkoutAnalyser {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct WorkoutResult {
        let zone2MinutesWeekly:    Double   // 30-day total ÷ 4.286 weeks
        let vigorousMinutesWeekly: Double
        let strengthSessionsWeekly: Double  // Double so fractional weeks average correctly
        let trainingLoadWeekly:    Double   // arbitrary units per week
    }

    // MARK: - Fetch

    func fetchWorkoutResult(userAge: Int) async -> WorkoutResult {
        let workouts = await fetchWorkouts(daysBack: 30)

        let maxHR             = Double(220 - userAge)
        let zone2Low          = maxHR * 0.60
        let zone2High         = maxHR * 0.70
        let vigorousThreshold = maxHR * 0.80

        var zone2Secs:    Double = 0
        var vigorousSecs: Double = 0
        var strengthCount        = 0
        var trainingLoad: Double = 0

        for workout in workouts {
            if isStrengthWorkout(workout) {
                strengthCount += 1
            }

            let hrSamples = await fetchHRSamples(for: workout)

            if hrSamples.isEmpty {
                if !isStrengthWorkout(workout) {
                    zone2Secs += workout.duration
                }
                continue
            }

            var z2Secs:  Double = 0
            var vigSecs: Double = 0
            var sumHR:   Double = 0
            var count    = 0

            for (index, sample) in hrSamples.enumerated() {
                let hr = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                sumHR += hr
                count += 1

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

            zone2Secs    += z2Secs
            vigorousSecs += vigSecs

            if count > 0 {
                let avgHRPct = (sumHR / Double(count)) / maxHR
                trainingLoad += avgHRPct * (workout.duration / 60)
            }
        }

        // Convert 30-day totals to weekly averages (30 days ÷ 7 days/week = 4.286 weeks)
        let weeks = 30.0 / 7.0
        return WorkoutResult(
            zone2MinutesWeekly:     (zone2Secs    / 60) / weeks,
            vigorousMinutesWeekly:  (vigorousSecs / 60) / weeks,
            strengthSessionsWeekly: Double(strengthCount) / weeks,
            trainingLoadWeekly:     trainingLoad / weeks
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
             .highIntensityIntervalTraining,
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

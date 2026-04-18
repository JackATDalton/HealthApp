import HealthKit

/// Derives Zone 2 minutes, vigorous minutes, strength sessions, and training load
/// from the last 30 days of Apple Watch workout data, expressed as weekly averages.
@MainActor
final class HealthKitWorkoutAnalyser {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct RecentWorkout: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let displayType: String
        let durationMinutes: Double
        let zone2Minutes: Double
        let vigorousMinutes: Double
        let avgHRPercent: Double   // 0–1 fraction of max HR
    }

    struct WorkoutResult {
        let zone2MinutesWeekly:    Double   // 30-day total ÷ 4.286 weeks
        let vigorousMinutesWeekly: Double
        let strengthSessionsWeekly: Double  // Double so fractional weeks average correctly
        let trainingLoadWeekly:    Double   // arbitrary units per week
        let recentWorkouts:        [RecentWorkout]  // last 7 workouts, newest first
    }

    // MARK: - Fetch

    func fetchWorkoutResult(userAge: Int) async -> WorkoutResult {
        let workouts = await fetchWorkouts(daysBack: 30)

        let maxHR             = Double(220 - userAge)
        // Apple Health zone definitions: zones divide 70–100% of maxHR into 4 equal 7.5% bands.
        // Zone 1: <70% | Zone 2: 70–77.5% | Zone 3: 77.5–85% | Zone 4: 85–92.5% | Zone 5: >92.5%
        let zone2Low          = maxHR * 0.700
        let zone2High         = maxHR * 0.775
        let vigorousThreshold = maxHR * 0.775  // Zone 3+ = vigorous

        var zone2Secs:    Double = 0
        var vigorousSecs: Double = 0
        var strengthCount        = 0
        var trainingLoad: Double = 0
        var recentWorkouts: [RecentWorkout] = []

        for workout in workouts {
            if isStrengthWorkout(workout) {
                strengthCount += 1
            }

            let hrSamples = await fetchHRSamples(for: workout)

            if hrSamples.isEmpty {
                if !isStrengthWorkout(workout) {
                    zone2Secs += workout.duration
                }
                if recentWorkouts.count < 7 {
                    recentWorkouts.append(RecentWorkout(
                        date: workout.startDate,
                        displayType: workoutDisplayName(workout),
                        durationMinutes: workout.duration / 60,
                        zone2Minutes: 0,
                        vigorousMinutes: 0,
                        avgHRPercent: 0
                    ))
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

            let avgHRPct: Double
            if count > 0 {
                avgHRPct = (sumHR / Double(count)) / maxHR
                trainingLoad += avgHRPct * (workout.duration / 60)
            } else {
                avgHRPct = 0
            }

            if recentWorkouts.count < 7 {
                recentWorkouts.append(RecentWorkout(
                    date: workout.startDate,
                    displayType: workoutDisplayName(workout),
                    durationMinutes: workout.duration / 60,
                    zone2Minutes: z2Secs / 60,
                    vigorousMinutes: vigSecs / 60,
                    avgHRPercent: avgHRPct
                ))
            }
        }

        // Convert 30-day totals to weekly averages (30 days ÷ 7 days/week = 4.286 weeks)
        let weeks = 30.0 / 7.0
        return WorkoutResult(
            zone2MinutesWeekly:     (zone2Secs    / 60) / weeks,
            vigorousMinutesWeekly:  (vigorousSecs / 60) / weeks,
            strengthSessionsWeekly: Double(strengthCount) / weeks,
            trainingLoadWeekly:     trainingLoad / weeks,
            recentWorkouts:         recentWorkouts
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

    private func workoutDisplayName(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running:                      return "Run"
        case .cycling:                      return "Cycle"
        case .walking:                      return "Walk"
        case .swimming:                     return "Swim"
        case .rowing:                       return "Row"
        case .elliptical:                   return "Elliptical"
        case .yoga:                         return "Yoga"
        case .pilates:                      return "Pilates"
        case .traditionalStrengthTraining:  return "Strength"
        case .functionalStrengthTraining:   return "Functional Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining:                 return "Core"
        case .crossTraining:                return "Cross Training"
        case .hiking:                       return "Hike"
        case .stairClimbing:                return "Stair Climb"
        case .jumpRope:                     return "Jump Rope"
        default:                            return "Workout"
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

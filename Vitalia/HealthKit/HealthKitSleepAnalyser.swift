import HealthKit

/// Parses raw HKCategorySample sleep data into per-session statistics.
@MainActor
final class HealthKitSleepAnalyser {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    // MARK: - Public output

    struct SleepSession {
        let date: Date          // calendar date this session "belongs to" (morning it ended)
        let startDate: Date     // bedtime — start of first sleep sample (used for consistency calc)
        let totalSleep: TimeInterval      // core + deep + REM, seconds
        let deepSleep: TimeInterval
        let remSleep: TimeInterval
        let lightSleep: TimeInterval      // asleepCore
        let awakeTime: TimeInterval       // awake during session
        let timeInBed: TimeInterval       // span from first to last sample

        var efficiency: Double { timeInBed > 0 ? min(totalSleep / timeInBed, 1.0) : 0 }
        var deepPct:    Double { totalSleep > 0 ? deepSleep  / totalSleep : 0 }
        var remPct:     Double { totalSleep > 0 ? remSleep   / totalSleep : 0 }
        var awakePct:   Double { timeInBed  > 0 ? awakeTime  / timeInBed  : 0 }
        var durationHours: Double { totalSleep / 3600 }
    }

    struct SleepResult {
        // Most recent night
        let lastNight: SleepSession?
        // 5-day rolling debt vs 7.5-hr target (minutes)
        let rollingDebtMinutes: Double
        // 7-day history
        let recent7Days: [SleepSession]
    }

    // MARK: - Fetch

    func fetchSleepResult() async -> SleepResult {
        let samples = await fetchRawSamples(daysBack: 10)
        let sessions = parseSessions(from: samples)
            .sorted { $0.date > $1.date }

        let lastNight = sessions.first
        let recent7 = Array(sessions.prefix(7))

        // 5-day rolling debt
        let targetSeconds = 7.5 * 3600
        let last5 = Array(sessions.prefix(5))
        let debt: Double
        if last5.isEmpty {
            debt = 0
        } else {
            let totalSleep = last5.reduce(0.0) { $0 + $1.totalSleep }
            let target = targetSeconds * Double(last5.count)
            debt = max(0, (target - totalSleep) / 60)   // minutes
        }

        return SleepResult(lastNight: lastNight, rollingDebtMinutes: debt, recent7Days: recent7)
    }

    // MARK: - Private parsing

    private func fetchRawSamples(daysBack: Int) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func parseSessions(from samples: [HKCategorySample]) -> [SleepSession] {
        guard !samples.isEmpty else { return [] }

        // Group samples into sessions: gap > 60 min = new session
        var sessionGroups: [[HKCategorySample]] = []
        var currentGroup: [HKCategorySample] = []

        for sample in samples {
            if let lastSample = currentGroup.last,
               sample.startDate.timeIntervalSince(lastSample.endDate) > 3600 {
                sessionGroups.append(currentGroup)
                currentGroup = [sample]
            } else {
                currentGroup.append(sample)
            }
        }
        if !currentGroup.isEmpty { sessionGroups.append(currentGroup) }

        // Parse each group into a SleepSession
        return sessionGroups.compactMap { group in
            guard let firstSample = group.first,
                  let lastSample  = group.last
            else { return nil }

            var deepSleep:  TimeInterval = 0
            var remSleep:   TimeInterval = 0
            var lightSleep: TimeInterval = 0
            var awakeTime:  TimeInterval = 0

            for sample in group {
                let dur = sample.endDate.timeIntervalSince(sample.startDate)
                guard dur > 0 else { continue }

                switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                case .asleepDeep:       deepSleep  += dur
                case .asleepREM:        remSleep   += dur
                case .asleepCore:       lightSleep += dur
                case .asleepUnspecified: lightSleep += dur   // fallback
                case .awake:            awakeTime  += dur
                default:                break   // inBed — not counted as sleep or awake
                }
            }

            let totalSleep = deepSleep + remSleep + lightSleep
            let timeInBed  = lastSample.endDate.timeIntervalSince(firstSample.startDate)

            guard totalSleep > 3600 else { return nil }     // filter out naps < 1 hr

            // Assign to calendar date of wake-up
            let wakeDate = Calendar.current.startOfDay(for: lastSample.endDate)

            return SleepSession(
                date:        wakeDate,
                startDate:   firstSample.startDate,
                totalSleep:  totalSleep,
                deepSleep:   deepSleep,
                remSleep:    remSleep,
                lightSleep:  lightSleep,
                awakeTime:   awakeTime,
                timeInBed:   timeInBed
            )
        }
    }
}

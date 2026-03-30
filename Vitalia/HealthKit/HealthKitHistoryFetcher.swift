import HealthKit
import Foundation

// MARK: - Time Range

enum MetricTimeRange: String, CaseIterable, Identifiable {
    case week      = "W"
    case month     = "M"
    case sixMonths = "6M"
    case year      = "Y"
    case allTime   = "All"

    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .week:       return cal.date(byAdding: .day,   value: -7,   to: Date())!
        case .month:      return cal.date(byAdding: .day,   value: -30,  to: Date())!
        case .sixMonths:  return cal.date(byAdding: .month, value: -6,   to: Date())!
        case .year:       return cal.date(byAdding: .year,  value: -1,   to: Date())!
        case .allTime:    return cal.date(byAdding: .year,  value: -10,  to: Date())!
        }
    }

    var intervalComponents: DateComponents {
        switch self {
        case .week, .month:     return DateComponents(day: 1)
        case .sixMonths, .year: return DateComponents(weekOfYear: 1)
        case .allTime:          return DateComponents(month: 1)
        }
    }

    var xAxisComponent: Calendar.Component {
        switch self {
        case .week:      return .day
        case .month:     return .weekOfYear
        case .sixMonths: return .month
        case .year:      return .month
        case .allTime:   return .year
        }
    }

    var xAxisStrideCount: Int {
        switch self {
        case .week:      return 1
        case .month:     return 1
        case .sixMonths: return 1
        case .year:      return 2
        case .allTime:   return 2
        }
    }

    var xAxisDateFormat: Date.FormatStyle {
        switch self {
        case .week:      return .dateTime.month(.abbreviated).day()
        case .month:     return .dateTime.day()
        case .sixMonths: return .dateTime.month(.abbreviated)
        case .year:      return .dateTime.month(.abbreviated)
        case .allTime:   return .dateTime.year()
        }
    }
}

// MARK: - History Point

struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Fetcher

/// Fetches per-period historical values for any MetricDefinition metric directly from HealthKit.
@MainActor
final class HealthKitHistoryFetcher {
    private let store: HKHealthStore
    private var bpm: HKUnit { .count().unitDivided(by: .minute()) }

    init(store: HKHealthStore) { self.store = store }

    // MARK: - Public

    func fetch(metricID: String, range: MetricTimeRange, userAge: Int = 35) async -> [HistoryPoint] {
        switch metricID {
        // Cardiovascular
        case "vo2max":
            return await quantityStats(.vo2Max, unit: .init(from: "ml/kg*min"), options: .discreteMax, range: range)
        case "rhr":
            return await quantityStats(.restingHeartRate, unit: bpm, options: .discreteMin, range: range)
        case "hrv":
            return await quantityStats(.heartRateVariabilitySDNN, unit: .init(from: "ms"), options: .discreteAverage, range: range)
        case "spo2":
            return await quantityStats(.oxygenSaturation, unit: .percent(), options: .discreteMin, range: range, scale: 100)
        case "walking_hr":
            return await quantityStats(.walkingHeartRateAverage, unit: bpm, options: .discreteAverage, range: range)
        case "cardio_recovery":
            return await quantityStats(.heartRateRecoveryOneMinute, unit: bpm, options: .discreteAverage, range: range)
        case "bloodpressure_sys":
            return await quantityStats(.bloodPressureSystolic, unit: .millimeterOfMercury(), options: .discreteAverage, range: range)
        case "respiratory_rate":
            return await quantityStats(.respiratoryRate, unit: bpm, options: .discreteAverage, range: range)

        // Activity
        case "steps":
            return await quantityStats(.stepCount, unit: .count(), options: .cumulativeSum, range: range)
        case "stand_hours":
            return await standHourHistory(range: range)
        case "daylight_exposure":
            return await quantityStats(.timeInDaylight, unit: .second(), options: .cumulativeSum, range: range, scale: 1.0 / 60.0)
        case "mindful_minutes":
            return await mindfulHistory(range: range)

        // Body composition — show body mass in kg for trend context
        case "bmi", "body_weight_trend":
            return await quantityStats(.bodyMass, unit: .gramUnit(with: .kilo), options: .discreteAverage, range: range)

        // Stress & recovery
        case "wrist_temp":
            return await quantityStats(.appleSleepingWristTemperature, unit: .degreeCelsius(), options: .discreteAverage, range: range)

        // Sleep
        case "sleep_duration":   return await sleepHistory(.duration,   range: range)
        case "sleep_efficiency": return await sleepHistory(.efficiency, range: range)
        case "deep_sleep_pct":   return await sleepHistory(.deepPct,    range: range)
        case "rem_sleep_pct":    return await sleepHistory(.remPct,     range: range)
        case "awake_pct":        return await sleepHistory(.awakePct,   range: range)

        // Workout-derived
        case "zone2_minutes":    return await workoutZoneHistory(vigorous: false, range: range, userAge: userAge)
        case "vigorous_minutes": return await workoutZoneHistory(vigorous: true,  range: range, userAge: userAge)
        case "strength_sessions":return await strengthCountHistory(range: range)
        case "training_load":    return await trainingLoadHistory(range: range, userAge: userAge)

        default: return []
        }
    }

    // MARK: - HKStatisticsCollectionQuery

    private func quantityStats(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        range: MetricTimeRange,
        scale: Double = 1.0
    ) async -> [HistoryPoint] {
        await withCheckedContinuation { continuation in
            let end    = Date()
            let start  = range.startDate
            let anchor = Calendar.current.startOfDay(for: end)
            let pred   = HKQuery.predicateForSamples(withStart: start, end: end)

            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: pred,
                options: options,
                anchorDate: anchor,
                intervalComponents: range.intervalComponents
            )

            query.initialResultsHandler = { _, collection, _ in
                guard let col = collection else { continuation.resume(returning: []); return }
                var pts: [HistoryPoint] = []
                col.enumerateStatistics(from: start, to: end) { stats, _ in
                    let raw: Double?
                    if options.contains(.cumulativeSum) {
                        raw = stats.sumQuantity()?.doubleValue(for: unit)
                    } else if options.contains(.discreteMin) {
                        raw = stats.minimumQuantity()?.doubleValue(for: unit)
                    } else if options.contains(.discreteMax) {
                        raw = stats.maximumQuantity()?.doubleValue(for: unit)
                    } else {
                        raw = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let v = raw {
                        pts.append(HistoryPoint(date: stats.startDate, value: v * scale))
                    }
                }
                continuation.resume(returning: pts)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Stand Hours

    private func standHourHistory(range: MetricTimeRange) async -> [HistoryPoint] {
        let samples = await categorySamples(.appleStandHour, from: range.startDate, to: Date())
        let pairs = samples
            .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
            .map { (Calendar.current.startOfDay(for: $0.startDate), 1.0) }
        // Sum stood-hours per period
        return aggregateByPeriod(pairs, range: range) { $0.reduce(0, +) }
    }

    // MARK: - Mindful Minutes

    private func mindfulHistory(range: MetricTimeRange) async -> [HistoryPoint] {
        let samples = await categorySamples(.mindfulSession, from: range.startDate, to: Date())
        let pairs = samples.map {
            (Calendar.current.startOfDay(for: $0.startDate),
             $0.endDate.timeIntervalSince($0.startDate) / 60.0)
        }
        return aggregateByPeriod(pairs, range: range) { $0.reduce(0, +) }
    }

    // MARK: - Sleep

    private enum SleepField { case duration, efficiency, deepPct, remPct, awakePct }

    private func sleepHistory(_ field: SleepField, range: MetricTimeRange) async -> [HistoryPoint] {
        let samples = await categorySamples(.sleepAnalysis, from: range.startDate, to: Date())
        let sessions = parseSleepSessions(from: samples)
        let pairs: [(Date, Double)] = sessions.map { s in
            let v: Double
            switch field {
            case .duration:   v = s.totalSleep / 3600
            case .efficiency: v = s.timeInBed > 0 ? min(s.totalSleep / s.timeInBed, 1) * 100 : 0
            case .deepPct:    v = s.totalSleep > 0 ? s.deepSleep / s.totalSleep * 100 : 0
            case .remPct:     v = s.totalSleep > 0 ? s.remSleep  / s.totalSleep * 100 : 0
            case .awakePct:   v = s.timeInBed  > 0 ? s.awakeTime / s.timeInBed  * 100 : 0
            }
            return (s.date, v)
        }
        // Average multiple sessions that fall in the same period bucket
        return aggregateByPeriod(pairs, range: range) { vals in
            vals.reduce(0, +) / Double(vals.count)
        }
    }

    // MARK: - Workout-derived

    private func workoutZoneHistory(vigorous: Bool, range: MetricTimeRange, userAge: Int) async -> [HistoryPoint] {
        let workouts  = await fetchWorkouts(from: range.startDate, limit: 250)
        let maxHR     = Double(220 - userAge)
        let z2Low     = maxHR * 0.60, z2High = maxHR * 0.70
        let vigThresh = maxHR * 0.80

        var pairs: [(Date, Double)] = []
        for workout in workouts where !isStrength(workout) {
            let hrSamples = await fetchHRSamples(for: workout)
            var secs = 0.0
            for (i, s) in hrSamples.enumerated() {
                let hr   = s.quantity.doubleValue(for: bpm)
                let next = i + 1 < hrSamples.count ? hrSamples[i+1].startDate : s.startDate.addingTimeInterval(5)
                let dur  = next.timeIntervalSince(s.startDate)
                guard dur > 0, dur < 120 else { continue }
                if vigorous  { if hr > vigThresh                  { secs += dur } }
                else         { if hr >= z2Low && hr <= z2High     { secs += dur } }
            }
            if secs > 0 {
                pairs.append((Calendar.current.startOfDay(for: workout.startDate), secs / 60.0))
            }
        }
        return aggregateByPeriod(pairs, range: range) { $0.reduce(0, +) }
    }

    private func strengthCountHistory(range: MetricTimeRange) async -> [HistoryPoint] {
        let workouts = await fetchWorkouts(from: range.startDate, limit: 500)
        let pairs = workouts
            .filter { isStrength($0) }
            .map { (Calendar.current.startOfDay(for: $0.startDate), 1.0) }
        return aggregateByPeriod(pairs, range: range) { $0.reduce(0, +) }
    }

    private func trainingLoadHistory(range: MetricTimeRange, userAge: Int) async -> [HistoryPoint] {
        let workouts = await fetchWorkouts(from: range.startDate, limit: 250)
        let maxHR    = Double(220 - userAge)
        var pairs: [(Date, Double)] = []
        for workout in workouts {
            let hrSamples = await fetchHRSamples(for: workout)
            guard !hrSamples.isEmpty else { continue }
            let avgHR = hrSamples.map { $0.quantity.doubleValue(for: bpm) }.reduce(0, +) / Double(hrSamples.count)
            let load  = (avgHR / maxHR) * (workout.duration / 60.0)
            pairs.append((Calendar.current.startOfDay(for: workout.startDate), load))
        }
        return aggregateByPeriod(pairs, range: range) { $0.reduce(0, +) }
    }

    // MARK: - Raw HK helpers

    private func categorySamples(_ type: HKCategoryTypeIdentifier, from start: Date, to end: Date) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(
                sampleType: HKCategoryType(type),
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
    }

    private func fetchWorkouts(from start: Date, limit: Int) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let q = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: pred,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
    }

    private func fetchHRSamples(for workout: HKWorkout) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let pred = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(
                sampleType: HKQuantityType(.heartRate),
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(q)
        }
    }

    private func isStrength(_ workout: HKWorkout) -> Bool {
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining,
             .highIntensityIntervalTraining, .coreTraining, .crossTraining:
            return true
        default: return false
        }
    }

    // MARK: - Period aggregation

    private func periodStart(for date: Date, range: MetricTimeRange) -> Date {
        let cal = Calendar.current
        let ic  = range.intervalComponents
        if ic.day != nil        { return cal.startOfDay(for: date) }
        if ic.weekOfYear != nil { return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date) }
        return cal.dateInterval(of: .month, for: date)?.start ?? cal.startOfDay(for: date)
    }

    private func aggregateByPeriod(
        _ values: [(Date, Double)],
        range: MetricTimeRange,
        combine: ([Double]) -> Double
    ) -> [HistoryPoint] {
        var buckets: [Date: [Double]] = [:]
        for (date, val) in values {
            buckets[periodStart(for: date, range: range), default: []].append(val)
        }
        return buckets
            .map { HistoryPoint(date: $0.key, value: combine($0.value)) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Sleep session parser (adapted from HealthKitSleepAnalyser)

    private struct ParsedSession {
        let date: Date
        let totalSleep: TimeInterval
        let deepSleep:  TimeInterval
        let remSleep:   TimeInterval
        let awakeTime:  TimeInterval
        let timeInBed:  TimeInterval
    }

    private func parseSleepSessions(from samples: [HKCategorySample]) -> [ParsedSession] {
        guard !samples.isEmpty else { return [] }
        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []

        for s in samples {
            if let last = current.last, s.startDate.timeIntervalSince(last.endDate) > 3600 {
                groups.append(current)
                current = [s]
            } else {
                current.append(s)
            }
        }
        if !current.isEmpty { groups.append(current) }

        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            var deep = 0.0, rem = 0.0, light = 0.0, awake = 0.0
            for s in group {
                let dur = s.endDate.timeIntervalSince(s.startDate)
                guard dur > 0 else { continue }
                switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                case .asleepDeep:        deep  += dur
                case .asleepREM:         rem   += dur
                case .asleepCore:        light += dur
                case .asleepUnspecified: light += dur
                case .awake:             awake += dur
                default:                 break
                }
            }
            let total = deep + rem + light
            guard total > 3600 else { return nil }
            return ParsedSession(
                date:       Calendar.current.startOfDay(for: last.endDate),
                totalSleep: total,
                deepSleep:  deep,
                remSleep:   rem,
                awakeTime:  awake,
                timeInBed:  last.endDate.timeIntervalSince(first.startDate)
            )
        }
    }
}

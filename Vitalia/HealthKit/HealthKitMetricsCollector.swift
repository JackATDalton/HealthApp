import HealthKit

/// Fetches all tracked metrics from HealthKit and returns a [metricID: Double] snapshot.
/// All queries run concurrently via async let.
@MainActor
final class HealthKitMetricsCollector {
    private let store: HKHealthStore
    private let sleepAnalyser: HealthKitSleepAnalyser
    private let workoutAnalyser: HealthKitWorkoutAnalyser

    init(store: HKHealthStore) {
        self.store = store
        self.sleepAnalyser  = HealthKitSleepAnalyser(store: store)
        self.workoutAnalyser = HealthKitWorkoutAnalyser(store: store)
    }

    // MARK: - Main collect

    func collect(userAge: Int) async -> [String: Double] {
        // Run all independent queries concurrently
        async let hrv         = fetchDailyAverage(.heartRateVariabilitySDNN, unit: .init(from: "ms"), daysBack: 2)
        async let rhr         = fetchDailyAverage(.restingHeartRate,         unit: heartRateUnit,    daysBack: 2)
        async let vo2max      = fetchMax(.vo2Max,              unit: .init(from: "ml/kg*min"),       daysBack: 30)
        async let spo2        = fetchOvernightMin(.oxygenSaturation, unit: .percent())
        async let walkingHR   = fetchDailyAverage(.appleWalkingHeartRateAverage, unit: heartRateUnit, daysBack: 7)
        async let cardioRecov = fetchLatestSample(.heartRateRecoveryOneMinute, unit: heartRateUnit)
        async let steps       = fetchDailySum(.stepCount, unit: .count(), daysBack: 1)
        async let activeEnergy = fetchDailySum(.activeEnergyBurned, unit: .kilocalorie(), daysBack: 1)
        async let respRate    = fetchOvernightAverage(.respiratoryRate, unit: heartRateUnit)
        async let standTime   = fetchDailySum(.appleStandTime, unit: .minute(), daysBack: 1)
        async let bodyMass    = fetchLatestSample(.bodyMass, unit: .gramUnit(with: .kilo))
        async let bmi         = fetchLatestSample(.bodyMassIndex, unit: .count())
        async let bodyFat     = fetchLatestSample(.bodyFatPercentage, unit: .percent())
        async let bpSystolic  = fetchLatestSample(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let bpDiastolic = fetchLatestSample(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let daylightSec = fetchDailySum(.timeInDaylight, unit: .second(), daysBack: 1)
        async let mindfulSec  = fetchMindfulMinutes(daysBack: 1)
        async let wristTemp   = fetchWristTemperatureDeviation()
        async let sleep       = sleepAnalyser.fetchSleepResult()
        async let workouts    = workoutAnalyser.fetchWorkoutResult(userAge: userAge)

        // Await all
        let hrvVal      = await hrv
        let rhrVal      = await rhr
        let vo2Val      = await vo2max
        let spo2Val     = await spo2
        let walkHRVal   = await walkingHR
        let recovVal    = await cardioRecov
        let stepsVal    = await steps
        let energyVal   = await activeEnergy
        let rrVal       = await respRate
        let standVal    = await standTime
        let massVal     = await bodyMass
        let bmiVal      = await bmi
        let fatVal      = await bodyFat
        let bpSysVal    = await bpSystolic
        let bpDiaVal    = await bpDiastolic
        let daylightVal = await daylightSec
        let mindfulVal  = await mindfulSec
        let wristVal    = await wristTemp
        let sleepResult = await sleep
        let workResult  = await workouts

        var snapshot: [String: Double] = [:]

        // Cardiovascular
        if let v = hrvVal     { snapshot["hrv"]             = v }
        if let v = rhrVal     { snapshot["rhr"]             = v }
        if let v = vo2Val     { snapshot["vo2max"]          = v }   // raw; correction applied in evaluator
        if let v = spo2Val    { snapshot["spo2"]            = v * 100 }   // 0‥1 → percentage
        if let v = walkHRVal  { snapshot["walking_hr"]      = v }
        if let v = recovVal   { snapshot["cardio_recovery"] = v }
        if let v = bpSysVal   { snapshot["bloodpressure_sys"] = v }
        if let v = bpDiaVal   { snapshot["bloodpressure_dia"] = v }

        // Activity
        if let v = stepsVal   { snapshot["steps"]           = v }
        if let v = energyVal  { snapshot["active_energy"]   = v }
        if let v = standVal   { snapshot["stand_hours"]     = v / 60 }    // minutes → hours
        snapshot["zone2_minutes"]    = workResult.zone2MinutesWeekly
        snapshot["vigorous_minutes"] = workResult.vigorousMinutesWeekly
        snapshot["strength_sessions"] = Double(workResult.strengthSessionsWeekly)
        snapshot["training_load"]    = workResult.trainingLoad7Day

        // Body composition
        if let v = massVal    { snapshot["body_weight_trend"] = v }
        if let v = bmiVal     { snapshot["bmi"]              = v }
        if let v = fatVal     { snapshot["body_fat"]         = v * 100 }  // 0‥1 → percentage

        // Sleep
        if let night = sleepResult.lastNight {
            snapshot["sleep_duration"]   = night.durationHours
            snapshot["sleep_efficiency"] = night.efficiency * 100
            snapshot["deep_sleep_pct"]   = night.deepPct * 100
            snapshot["rem_sleep_pct"]    = night.remPct  * 100
            snapshot["awake_pct"]        = night.awakePct * 100
        }
        snapshot["sleep_debt"] = sleepResult.rollingDebtMinutes

        // Sleep / Stress
        if let v = rrVal      { snapshot["respiratory_rate"] = v }
        if let v = wristVal   { snapshot["wrist_temp"]       = v }

        // Stress & Recovery
        if let v = mindfulVal { snapshot["mindful_minutes"]  = v }
        if let v = daylightVal { snapshot["daylight_exposure"] = v / 60 }  // seconds → minutes

        return snapshot
    }

    // MARK: - Generic query helpers

    private var heartRateUnit: HKUnit { .count().unitDivided(by: .minute()) }

    /// Latest single sample value.
    private func fetchLatestSample(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(id),
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Average of all samples in the last N days.
    private func fetchDailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Max value across last N days (used for VO₂ Max).
    private func fetchMax(_ id: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, stats, _ in
                let value = stats?.maximumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Cumulative sum for today (steps, energy, etc.).
    private func fetchDailySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Minimum SpO₂ or similar during overnight window (21:00–09:00).
    private func fetchOvernightMin(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let (start, end) = overnightWindow()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteMin
            ) { _, stats, _ in
                let value = stats?.minimumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Average of samples in the overnight window (used for RR, HRV overnight).
    private func fetchOvernightAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let (start, end) = overnightWindow()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Total mindful session duration today, in minutes.
    private func fetchMindfulMinutes(daysBack: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.mindfulSession),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sessions = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let totalSeconds = sessions.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
                continuation.resume(returning: totalSeconds / 60)
            }
            store.execute(query)
        }
    }

    /// Wrist temperature deviation from 30-day baseline (Series 8+ only).
    private func fetchWristTemperatureDeviation() async -> Double? {
        guard HKQuantityType.isIdentifierValid(
            HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue
        ) else { return nil }

        let (recentStart, recentEnd) = overnightWindow()

        async let todayTemp    = fetchOvernightAvg_wristTemp(from: recentStart, to: recentEnd)
        async let baselineTemp = fetchWristTempBaseline()

        guard let today = await todayTemp, let baseline = await baselineTemp else { return nil }
        return today - baseline
    }

    private func fetchOvernightAvg_wristTemp(from start: Date, to end: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(.appleSleepingWristTemperature),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: .degreeCelsius()))
            }
            store.execute(query)
        }
    }

    private func fetchWristTempBaseline() async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(.appleSleepingWristTemperature),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: .degreeCelsius()))
            }
            store.execute(query)
        }
    }

    // MARK: - Helpers

    /// Returns start/end for the most recent overnight window (yesterday 21:00 → today 09:00).
    private func overnightWindow() -> (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        let todayMorning = cal.date(bySettingHour: 9,  minute: 0, second: 0, of: now)!
        let lastEvening  = cal.date(bySettingHour: 21, minute: 0, second: 0,
                                    of: cal.date(byAdding: .day, value: -1, to: now)!)!
        return (lastEvening, todayMorning)
    }
}

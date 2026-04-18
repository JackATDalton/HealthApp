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

    func collect(userAge: Int) async -> (snapshot: [String: Double], recentWorkouts: [HealthKitWorkoutAnalyser.RecentWorkout]) {
        // Phase 1: all queries that don't depend on the sleep window run fully concurrently.
        async let hrvBaseline    = fetchDailyAverage(.heartRateVariabilitySDNN, unit: .init(from: "ms"), daysBack: 30)
        async let hrvLongtermAvg = fetchAllTimeAverage(.heartRateVariabilitySDNN, unit: .init(from: "ms"))
        async let rhrBaseline    = fetchDailyAverage(.restingHeartRate,          unit: heartRateUnit,    daysBack: 30)
        async let rrBaseline     = fetchDailyAverage(.respiratoryRate,           unit: heartRateUnit,    daysBack: 30)
        async let vo2max         = fetchMax(.vo2Max, unit: .init(from: "ml/kg*min"), daysBack: 30)
        async let walkingHR      = fetchDailyAverage(.walkingHeartRateAverage,   unit: heartRateUnit,    daysBack: 30)
        async let cardioRecov    = fetchLatestSample(.heartRateRecoveryOneMinute, unit: heartRateUnit)
        async let steps          = fetchDailyAverageSum(.stepCount,              unit: .count(),         daysBack: 30)
        async let activeEnergy   = fetchDailyAverageSum(.activeEnergyBurned,     unit: .kilocalorie(),   daysBack: 30)
        async let weightChange   = fetchWeightChangePercent6M()
        async let bodyMass       = fetchLatestSample(.bodyMass,          unit: .gramUnit(with: .kilo))
        async let heightM        = fetchLatestSample(.height,            unit: .meter())
        async let bodyFat        = fetchLatestSample(.bodyFatPercentage, unit: .percent())
        async let bpSystolic     = fetchLatestSample(.bloodPressureSystolic,  unit: .millimeterOfMercury())
        async let bpDiastolic    = fetchLatestSample(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let daylightSec    = fetchDailyAverageSum(.timeInDaylight, unit: .second(), daysBack: 30)
        async let mindfulSec     = fetchMindfulAverageMinutes(daysBack: 30)
        async let wristTemp      = fetchWristTemperatureDeviation()
        async let sleep          = sleepAnalyser.fetchSleepResult()
        async let workouts       = workoutAnalyser.fetchWorkoutResult(userAge: userAge)

        // Await sleep first — its exact window anchors the phase-2 overnight queries.
        let sleepResult  = await sleep
        let lastNight    = sleepResult.lastNight

        // Phase 2: overnight cardio metrics anchored to the actual sleep session.
        // Falls back to the fixed 21:00–09:00 window when no sleep session is available.
        // RHR uses raw heartRate (average while asleep), not the once-per-day restingHeartRate sample.
        async let hrvLastNight  = fetchDuringSleepAverage(.heartRateVariabilitySDNN, unit: .init(from: "ms"), sleep: lastNight)
        async let rhrLastNight  = fetchDuringSleepAverage(.heartRate,                unit: heartRateUnit,     sleep: lastNight)
        async let rrLastNight   = fetchDuringSleepAverage(.respiratoryRate,          unit: heartRateUnit,     sleep: lastNight)
        async let spo2LastNight = fetchDuringSleepMin(.oxygenSaturation,             unit: .percent(),        sleep: lastNight)

        // Await phase 1
        let hrvBaselineVal    = await hrvBaseline
        let hrvLongtermAvgVal = await hrvLongtermAvg
        let rhrBaselineVal    = await rhrBaseline
        let rrBaselineVal     = await rrBaseline
        let vo2Val            = await vo2max
        let walkHRVal         = await walkingHR
        let recovVal          = await cardioRecov
        let stepsVal          = await steps
        let energyVal         = await activeEnergy
        let weightChangeVal   = await weightChange
        let massVal           = await bodyMass
        let heightVal         = await heightM
        let fatVal            = await bodyFat
        let bpSysVal          = await bpSystolic
        let bpDiaVal          = await bpDiastolic
        let daylightVal       = await daylightSec
        let mindfulVal        = await mindfulSec
        let wristVal          = await wristTemp
        let workResult        = await workouts

        // Await phase 2
        let hrvTodayVal  = await hrvLastNight
        let rhrTodayVal  = await rhrLastNight
        let rrVal        = await rrLastNight
        let spo2Val      = await spo2LastNight

        var snapshot: [String: Double] = [:]

        // Cardiovascular
        // hrv / rhr: 30-day average is the primary value shown on dashboard and used in longevity score.
        // _today keys hold last-night sleep readings used by RecoveryScoreCalculator and the detail view.
        if let v = hrvBaselineVal    { snapshot["hrv"]                   = v }   // 30-day avg (primary)
        if let v = rhrBaselineVal    { snapshot["rhr"]                   = v }   // 30-day avg (primary)
        if let v = hrvTodayVal       { snapshot["hrv_today"]             = v }   // avg during sleep (recovery / detail)
        if let v = rhrTodayVal       { snapshot["rhr_today"]             = v }   // avg HR during sleep (recovery / detail)
        if let v = hrvBaselineVal    { snapshot["hrv_baseline"]          = v }
        if let v = hrvLongtermAvgVal { snapshot["hrv_longterm_baseline"] = v }
        if let v = rhrBaselineVal    { snapshot["rhr_baseline"]          = v }
        if let v = rrBaselineVal     { snapshot["rr_baseline"]           = v }
        if let v = vo2Val            { snapshot["vo2max"]                = v }
        if let v = spo2Val           { snapshot["spo2"]                  = v * 100 }   // 0‥1 → percentage
        if let v = walkHRVal         { snapshot["walking_hr"]            = v }
        if let v = recovVal          { snapshot["cardio_recovery"]       = v }
        if let v = bpSysVal          { snapshot["bloodpressure_sys"]     = v }
        if let v = bpDiaVal          { snapshot["bloodpressure_dia"]     = v }

        // Activity — all 30-day daily averages
        if let v = stepsVal  { snapshot["steps"]         = v }
        if let v = energyVal { snapshot["active_energy"] = v }
        snapshot["zone2_minutes"]     = workResult.zone2MinutesWeekly
        snapshot["vigorous_minutes"]  = workResult.vigorousMinutesWeekly
        snapshot["strength_sessions"] = workResult.strengthSessionsWeekly
        snapshot["training_load"]     = workResult.trainingLoadWeekly

        // Body composition — BMI computed from latest height + mass; falls back to nil if unavailable
        if let v = weightChangeVal { snapshot["body_weight_trend"] = v }
        if let mass = massVal, let height = heightVal, height > 0 {
            snapshot["bmi"] = mass / (height * height)
        }
        if let v = fatVal { snapshot["body_fat"] = v * 100 }                   // 0‥1 → percentage

        // Sleep
        if let night = sleepResult.lastNight {
            snapshot["sleep_duration"]   = night.durationHours
            snapshot["sleep_efficiency"] = night.efficiency * 100
            snapshot["deep_sleep_pct"]   = night.deepPct  * 100
            snapshot["rem_sleep_pct"]    = night.remPct   * 100
            snapshot["awake_pct"]        = night.awakePct * 100
        }
        snapshot["sleep_debt"] = sleepResult.rollingDebtMinutes
        if let consistency = sleepConsistencyMinutes(from: sleepResult.recent7Days) {
            snapshot["sleep_consistency"] = consistency
        }

        // Sleep / Stress
        if let v = rrVal    { snapshot["respiratory_rate"] = v }
        if let v = wristVal { snapshot["wrist_temp"]       = v }

        // Stress & Recovery — 30-day daily averages
        if let v = mindfulVal  { snapshot["mindful_minutes"]  = v }
        if let v = daylightVal { snapshot["daylight_exposure"] = v / 60 }      // avg daily seconds → minutes

        return (snapshot, workResult.recentWorkouts)
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

    /// Average across all available HealthKit data (no start-date filter) — used for long-term baselines.
    private func fetchAllTimeAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: nil,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
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

    /// Total cumulative sum over the last N days.
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

    /// Average daily sum over the last N days (total ÷ N).
    /// Use for step count, stand time, daylight, etc.
    private func fetchDailyAverageSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async -> Double? {
        guard let total = await fetchDailySum(id, unit: unit, daysBack: daysBack) else { return nil }
        return total / Double(daysBack)
    }

    /// Average of samples during the last sleep session.
    /// Falls back to the fixed overnight window (yesterday 21:00 – today 09:00) when no sleep session is available.
    private func fetchDuringSleepAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                                         sleep: HealthKitSleepAnalyser.SleepSession?) async -> Double? {
        let (start, end) = sleep.map { ($0.startDate, $0.endDate) } ?? overnightWindow()
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Minimum value of samples during the last sleep session.
    /// Falls back to the fixed overnight window when no sleep session is available.
    private func fetchDuringSleepMin(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                                     sleep: HealthKitSleepAnalyser.SleepSession?) async -> Double? {
        let (start, end) = sleep.map { ($0.startDate, $0.endDate) } ?? overnightWindow()
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteMin
            ) { _, stats, _ in
                continuation.resume(returning: stats?.minimumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Average daily mindful session minutes over the last N days.
    private func fetchMindfulAverageMinutes(daysBack: Int) async -> Double? {
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
                continuation.resume(returning: (totalSeconds / 60) / Double(daysBack))
            }
            store.execute(query)
        }
    }

    /// Wrist temperature deviation from 30-day baseline (Series 8+ only).
    private func fetchWristTemperatureDeviation() async -> Double? {
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

    /// Standard deviation of bedtimes (in minutes) across the last N sleep sessions.
    /// Bedtimes are expressed as minutes after 18:00 to avoid midnight wraparound.
    /// Returns nil if fewer than 3 sessions are available.
    private func sleepConsistencyMinutes(from sessions: [HealthKitSleepAnalyser.SleepSession]) -> Double? {
        guard sessions.count >= 3 else { return nil }
        let cal = Calendar.current
        let referenceHour = 18  // 6pm — earlier than any realistic bedtime

        let bedtimeOffsets: [Double] = sessions.map { session in
            let comps = cal.dateComponents([.hour, .minute], from: session.startDate)
            let hour   = comps.hour   ?? 0
            let minute = comps.minute ?? 0
            var offset = Double((hour - referenceHour) * 60 + minute)
            if offset < 0 { offset += 24 * 60 }   // shouldn't occur with 6pm reference
            return offset
        }

        let mean     = bedtimeOffsets.reduce(0, +) / Double(bedtimeOffsets.count)
        let variance = bedtimeOffsets.reduce(0) { $0 + pow($1 - mean, 2) } / Double(bedtimeOffsets.count)
        return sqrt(variance)
    }


    /// Absolute % change in body weight between recent 14-day average and 6-month-ago 30-day window.
    /// Returns nil if either window has no data.
    private func fetchWeightChangePercent6M() async -> Double? {
        let now = Date()
        let cal = Calendar.current
        let recentStart   = cal.date(byAdding: .day, value: -14,  to: now)!
        let historicEnd   = cal.date(byAdding: .day, value: -165, to: now)!
        let historicStart = cal.date(byAdding: .day, value: -195, to: now)!

        async let recent   = fetchAverageInRange(.bodyMass, unit: .gramUnit(with: .kilo), from: recentStart,   to: now)
        async let historic = fetchAverageInRange(.bodyMass, unit: .gramUnit(with: .kilo), from: historicStart, to: historicEnd)

        guard let r = await recent, let h = await historic, h > 0 else { return nil }
        return abs((r - h) / h) * 100
    }

    /// Average of all samples in a specific date range.
    private func fetchAverageInRange(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
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

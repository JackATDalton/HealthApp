import Foundation

/// Computes the daily Recovery Score (0–100) from 7 overnight inputs
/// relative to the user's own 30-day personal baselines.
enum RecoveryScoreCalculator {

    struct Inputs {
        // Today's overnight values (nil = unavailable)
        var hrv:              Double?   // ms
        var rhr:              Double?   // bpm (average heart rate during sleep)
        var sleepEfficiency:  Double?   // 0–100
        var deepSleepPct:     Double?   // 0–100
        var awakePct:         Double?   // 0–100 (of time in bed)
        var sleepDebtMinutes: Double?   // rolling 5-day deficit
        var respiratoryRate:  Double?   // breaths/min
        var spo2:             Double?   // 0–100 (overnight min)
        var wristTempDev:     Double?   // °C deviation from baseline

        // 30-day personal baselines
        var hrvBaseline:  Double?
        var rhrBaseline:  Double?
        var rrBaseline:   Double?
    }

    static func calculate(inputs: Inputs) -> RecoveryScoreResult {
        // Base weights
        var weights: [String: Double] = [
            "hrv":          0.35,
            "rhr":          0.25,
            "sleepQuality": 0.20,
            "sleepDebt":    0.10,
            "rr":           0.05,
            "spo2":         0.03,
            "wristTemp":    0.02,
        ]

        var componentScores: [String: Double?] = [
            "hrv":          scoreHRV(inputs),
            "rhr":          scoreRHR(inputs),
            "sleepQuality": scoreSleepQuality(inputs),
            "sleepDebt":    scoreSleepDebt(inputs),
            "rr":           scoreRespiratoryRate(inputs),
            "spo2":         scoreSPO2(inputs),
            "wristTemp":    scoreWristTemp(inputs),
        ]

        // Identify missing critical inputs
        var missing: [String] = []
        let criticalMissing = componentScores["hrv"] == nil
            && componentScores["rhr"] == nil
            && componentScores["sleepQuality"] == nil
        if criticalMissing {
            missing.append("HRV, Resting HR, and Sleep data are all unavailable.")
        }

        // Redistribute weights for unavailable inputs
        var redistribution = 0.0
        for (key, score) in componentScores where score == nil {
            redistribution += weights[key] ?? 0
            weights[key] = 0
        }
        // Spread redistributed weight proportionally over available inputs
        let available = weights.filter { $0.value > 0 }
        let availableSum = available.values.reduce(0, +)
        if availableSum > 0 && redistribution > 0 {
            for key in available.keys {
                weights[key] = (weights[key] ?? 0) + redistribution * ((weights[key] ?? 0) / availableSum)
            }
        }

        // Weighted sum
        var total = 0.0
        for (key, weight) in weights {
            guard weight > 0, let score = componentScores[key] as? Double else { continue }
            total += score * weight
        }
        let finalScore = max(0, min(100, total.rounded()))

        // Band
        let band: RecoveryBand
        switch finalScore {
        case 85...: band = .recovered
        case 65...: band = .moderate
        case 40...: band = .fatigued
        default:    band = .underRecovered
        }

        let breakdown = RecoveryInputBreakdown(
            hrvScore:             componentScores["hrv"]          as? Double,
            rhrScore:             componentScores["rhr"]          as? Double,
            sleepQualityScore:    componentScores["sleepQuality"] as? Double,
            sleepDebtScore:       componentScores["sleepDebt"]    as? Double,
            respiratoryRateScore: componentScores["rr"]           as? Double,
            spo2Score:            componentScores["spo2"]         as? Double,
            wristTempScore:       componentScores["wristTemp"]    as? Double,
            activeWeights: weights
        )

        return RecoveryScoreResult(
            score: finalScore,
            band: band,
            inputs: breakdown,
            incompleteReasons: missing
        )
    }

    // MARK: - Convenience init from snapshot dict

    static func inputs(from snapshot: [String: Double]) -> Inputs {
        Inputs(
            hrv:              snapshot["hrv_today"],   // overnight reading (primary dashboard value is now 30-day avg)
            rhr:              snapshot["rhr_today"],   // overnight min
            sleepEfficiency:  snapshot["sleep_efficiency"],
            deepSleepPct:     snapshot["deep_sleep_pct"],
            awakePct:         snapshot["awake_pct"],
            sleepDebtMinutes: snapshot["sleep_debt"],
            respiratoryRate:  snapshot["respiratory_rate"],
            spo2:             snapshot["spo2"],
            wristTempDev:     snapshot["wrist_temp"],
            hrvBaseline:      snapshot["hrv_baseline"],
            rhrBaseline:      snapshot["rhr_baseline"],
            rrBaseline:       snapshot["rr_baseline"]
        )
    }

    // MARK: - Component scorers (all return 0–100 or nil)

    private static func scoreHRV(_ i: Inputs) -> Double? {
        guard let hrv = i.hrv, let baseline = i.hrvBaseline, baseline > 0 else { return nil }
        let ratio = hrv / baseline
        let score: Double
        switch ratio {
        case 1.20...:       score = 100
        case 1.00..<1.20:   score = 80 + (ratio - 1.0)  / 0.20 * 20
        case 0.80..<1.00:   score = 50 + (ratio - 0.80) / 0.20 * 30
        case 0.60..<0.80:   score = 20 + (ratio - 0.60) / 0.20 * 30
        default:            score = max(0, ratio / 0.60 * 20)
        }
        return max(0, min(100, score))
    }

    private static func scoreRHR(_ i: Inputs) -> Double? {
        guard let rhr = i.rhr, let baseline = i.rhrBaseline else { return nil }
        let delta = rhr - baseline   // negative = better than baseline
        let score: Double
        switch delta {
        case ...(-3):       score = 100
        case -3..<0:        score = 75 + (-delta / 3) * 25
        case 0..<5:         score = 75 - (delta / 5) * 40
        default:            score = max(0, 35 - (delta - 5) * 7)
        }
        return max(0, min(100, score))
    }

    private static func scoreSleepQuality(_ i: Inputs) -> Double? {
        guard let eff = i.sleepEfficiency else { return nil }
        let deep  = i.deepSleepPct ?? 15       // use modest default if unavailable
        let awake = i.awakePct     ?? 8

        let effScore:   Double = clamp((eff   - 70) / (95 - 70) * 100, 0, 100)
        let deepScore:  Double = clamp((deep  - 10) / (25 - 10) * 100, 0, 100)
        let awakeScore: Double = clamp((10 - awake) / (10 - 2)  * 100, 0, 100)

        return effScore * 0.40 + deepScore * 0.40 + awakeScore * 0.20
    }

    private static func scoreSleepDebt(_ i: Inputs) -> Double? {
        guard let debt = i.sleepDebtMinutes else { return nil }
        let score: Double
        switch debt {
        case ...0:          score = 100
        case 0..<30:        score = 100 - debt / 30 * 25
        case 30..<90:       score = 75  - (debt - 30)  / 60 * 40
        default:            score = max(0, 35 - (debt - 90) * 0.35)
        }
        return max(0, min(100, score))
    }

    private static func scoreRespiratoryRate(_ i: Inputs) -> Double? {
        guard let rr = i.respiratoryRate else { return nil }
        let baseline = i.rrBaseline ?? 14.0
        let delta = rr - baseline   // positive = elevated (bad), negative = lower (neutral/good)
        let score: Double
        switch delta {
        case ...0.5:    score = 100             // at or below baseline — no penalty
        case 0.5..<2.0: score = 100 - (delta - 0.5) / 1.5 * 50
        default:        score = max(0, 50 - (delta - 2.0) * 15)
        }
        return max(0, min(100, score))
    }

    private static func scoreSPO2(_ i: Inputs) -> Double? {
        guard let spo2 = i.spo2 else { return nil }
        let score: Double
        switch spo2 {
        case 97...:     score = 100
        case 95..<97:   score = 100 - (97 - spo2) / 2 * 40
        case 90..<95:   score = 60  - (95 - spo2) / 5 * 50
        default:        score = max(0, 10 - (90 - spo2) * 2)
        }
        return max(0, min(100, score))
    }

    private static func scoreWristTemp(_ i: Inputs) -> Double? {
        guard let dev = i.wristTempDev else { return nil }
        let absDev = abs(dev)
        let score: Double
        switch absDev {
        case ...0.3:    score = 100
        case 0.3..<0.8: score = 100 - (absDev - 0.3) / 0.5 * 50
        default:        score = max(0, 50 - (absDev - 0.8) * 50)
        }
        return max(0, min(100, score))
    }

    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, value))
    }
}

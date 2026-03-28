import Foundation

enum RecoveryBand: String, Codable {
    case recovered      = "Recovered"
    case moderate       = "Moderate"
    case fatigued       = "Fatigued"
    case underRecovered = "Under-Recovered"

    var recommendation: String {
        switch self {
        case .recovered:      "Push hard today — good conditions for high-intensity training."
        case .moderate:       "Normal training is fine. Avoid max-effort sessions."
        case .fatigued:       "Prioritise Zone 2 or active recovery. Investigate your sleep."
        case .underRecovered: "Rest day recommended. Your body needs more time to recover."
        }
    }
}

struct RecoveryInputBreakdown: Codable {
    var hrvScore: Double?
    var rhrScore: Double?
    var sleepQualityScore: Double?
    var sleepDebtScore: Double?
    var respiratoryRateScore: Double?
    var spo2Score: Double?
    var wristTempScore: Double?
    var activeWeights: [String: Double]

    var sortedInputs: [(name: String, score: Double?, weight: Double)] {
        let pairs: [(String, Double?, String)] = [
            ("HRV",           hrvScore,            "hrv"),
            ("Resting HR",    rhrScore,             "rhr"),
            ("Sleep Quality", sleepQualityScore,    "sleepQuality"),
            ("Sleep Debt",    sleepDebtScore,       "sleepDebt"),
            ("Resp. Rate",    respiratoryRateScore, "rr"),
            ("SpO₂",          spo2Score,            "spo2"),
            ("Wrist Temp",    wristTempScore,       "wristTemp"),
        ]
        return pairs.map { (name: $0.0, score: $0.1, weight: activeWeights[$0.2] ?? 0) }
            .filter { $0.weight > 0 }
            .sorted { ($0.weight) > ($1.weight) }
    }
}

struct RecoveryScoreResult {
    let score: Double
    let band: RecoveryBand
    let inputs: RecoveryInputBreakdown
    let incompleteReasons: [String]

    var isIncomplete: Bool { !incompleteReasons.isEmpty }

    static let mock = RecoveryScoreResult(
        score: 72,
        band: .moderate,
        inputs: RecoveryInputBreakdown(
            hrvScore: 81, rhrScore: 74, sleepQualityScore: 65,
            sleepDebtScore: 90, respiratoryRateScore: 95,
            spo2Score: 100, wristTempScore: 88,
            activeWeights: ["hrv": 0.35, "rhr": 0.25, "sleepQuality": 0.20,
                            "sleepDebt": 0.10, "rr": 0.05, "spo2": 0.03, "wristTemp": 0.02]
        ),
        incompleteReasons: []
    )
}

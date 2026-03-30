import Foundation

enum MetricCategory: String, CaseIterable {
    case cardiovascular  = "Cardiovascular"
    case sleep           = "Sleep"
    case activity        = "Activity"
    case bodyComposition = "Body Composition"
    case stressRecovery  = "Stress & Recovery"
}

enum EvidenceTier: Int, Codable {
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3

    var label: String { "T\(rawValue)" }
    var weight: Double {
        switch self {
        case .tier1: 3.0
        case .tier2: 2.0
        case .tier3: 1.0
        }
    }
}

struct MetricDefinition: Identifiable {
    let id: String
    let displayName: String
    let unit: String
    let category: MetricCategory
    let evidenceTier: EvidenceTier
    let optimalLow: Double?
    let optimalHigh: Double?
    let higherIsBetter: Bool
    let description: String
    let longevityContext: String

    static let all: [MetricDefinition] = [
        // MARK: - Cardiovascular
        .init(id: "vo2max", displayName: "VO₂ Max", unit: "mL/kg/min",
              category: .cardiovascular, evidenceTier: .tier1,
              optimalLow: 55, optimalHigh: nil,
              higherIsBetter: true,
              description: "Maximal oxygen uptake during exercise.",
              longevityContext: "Strongest single predictor of all-cause mortality. Top 2.5% VO₂ Max associates with ~5× lower risk vs bottom quartile. Apple Watch value adjusted +3.5 mL/kg/min for known underestimation."),

        .init(id: "rhr", displayName: "Resting Heart Rate", unit: "bpm",
              category: .cardiovascular, evidenceTier: .tier1,
              optimalLow: 45, optimalHigh: 50,
              higherIsBetter: false,
              description: "Heart rate at complete rest.",
              longevityContext: "Every 10 bpm increase in RHR above 45 associates with ~16% increased cardiovascular mortality. Optimal range is 45–50 bpm."),

        .init(id: "hrv", displayName: "Heart Rate Variability", unit: "ms",
              category: .cardiovascular, evidenceTier: .tier1,
              optimalLow: nil, optimalHigh: nil,
              higherIsBetter: true,
              description: "Milliseconds variation between heartbeats (SDNN overnight).",
              longevityContext: "Reflects autonomic nervous system balance. Higher HRV associates with lower all-cause mortality and better cardiovascular health. Scored relative to personal baseline."),

        .init(id: "bloodpressure_sys", displayName: "Systolic BP", unit: "mmHg",
              category: .cardiovascular, evidenceTier: .tier1,
              optimalLow: 100, optimalHigh: 120,
              higherIsBetter: false,
              description: "Peak arterial pressure during heartbeat.",
              longevityContext: "Strongest modifiable risk factor for cardiovascular disease and stroke. Optimal is ≤120/80, with longevity data suggesting ~110/70 as ideal."),

        .init(id: "spo2", displayName: "Blood Oxygen", unit: "%",
              category: .cardiovascular, evidenceTier: .tier1,
              optimalLow: 97, optimalHigh: 100,
              higherIsBetter: true,
              description: "Percentage of haemoglobin carrying oxygen.",
              longevityContext: "Chronic low SpO₂ is associated with increased all-cause mortality. Overnight dips below 90% are a sleep apnoea red flag."),

        .init(id: "walking_hr", displayName: "Walking Heart Rate", unit: "bpm",
              category: .cardiovascular, evidenceTier: .tier2,
              optimalLow: nil, optimalHigh: 70,
              higherIsBetter: false,
              description: "Average heart rate during casual walking.",
              longevityContext: "Downward trend reflects improving cardiovascular efficiency."),

        .init(id: "cardio_recovery", displayName: "Cardio Recovery", unit: "bpm/min",
              category: .cardiovascular, evidenceTier: .tier2,
              optimalLow: 20, optimalHigh: nil,
              higherIsBetter: true,
              description: "Heart rate drop in the first minute after peak exercise.",
              longevityContext: "HR recovery < 12 bpm in 1 minute is an independent predictor of mortality (Cole et al., NEJM 1999)."),

        // MARK: - Sleep
        .init(id: "sleep_duration", displayName: "Sleep Duration", unit: "hrs",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 7, optimalHigh: 8.5,
              higherIsBetter: true,
              description: "Total time asleep per night.",
              longevityContext: "U-shaped mortality curve. Both <6 hrs and >9 hrs associate with higher all-cause mortality. Optimal window is 7–8.5 hrs."),

        .init(id: "sleep_efficiency", displayName: "Sleep Efficiency", unit: "%",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 90, optimalHigh: 100,
              higherIsBetter: true,
              description: "Percentage of time in bed actually asleep.",
              longevityContext: "Low efficiency reflects fragmented sleep; strongly associated with metabolic and cardiovascular disease risk."),

        .init(id: "deep_sleep_pct", displayName: "Deep Sleep", unit: "% of night",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 20, optimalHigh: 30,
              higherIsBetter: true,
              description: "Percentage of total sleep in deep (slow-wave) stage.",
              longevityContext: "Deep sleep is critical for cellular repair, HGH secretion, and memory consolidation. Declines with age."),

        .init(id: "rem_sleep_pct", displayName: "REM Sleep", unit: "% of night",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 20, optimalHigh: 25,
              higherIsBetter: true,
              description: "Percentage of sleep in REM stage.",
              longevityContext: "REM sleep is essential for emotional regulation and memory. Low REM associated with increased dementia risk."),

        .init(id: "awake_pct", displayName: "Awake During Night", unit: "% of night",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 0, optimalHigh: 5,
              higherIsBetter: false,
              description: "Percentage of time in bed spent awake.",
              longevityContext: "Frequent awakenings disrupt restorative sleep cycles and are associated with elevated cortisol and inflammation."),

        .init(id: "sleep_debt", displayName: "5-Day Sleep Debt", unit: "min",
              category: .sleep, evidenceTier: .tier1,
              optimalLow: 0, optimalHigh: 30,
              higherIsBetter: false,
              description: "Cumulative sleep deficit vs 7.5-hr target over last 5 nights.",
              longevityContext: "Cumulative sleep restriction impairs cognition, metabolism, and immune function even when individual nights appear normal."),

        .init(id: "sleep_consistency", displayName: "Sleep Consistency", unit: "min variance",
              category: .sleep, evidenceTier: .tier2,
              optimalLow: 0, optimalHigh: 20,
              higherIsBetter: false,
              description: "Standard deviation of bedtime across last 7 nights.",
              longevityContext: "Irregular sleep timing disrupts circadian rhythms, a key driver of metabolic and cardiovascular disease."),

        .init(id: "respiratory_rate", displayName: "Respiratory Rate", unit: "br/min",
              category: .sleep, evidenceTier: .tier2,
              optimalLow: 12, optimalHigh: 15,
              higherIsBetter: false,
              description: "Breathing rate during sleep.",
              longevityContext: "Stable overnight respiratory rate signals healthy sleep. Elevation is an early indicator of illness, stress, or sleep apnoea."),

        // MARK: - Activity
        .init(id: "steps", displayName: "Daily Steps", unit: "steps",
              category: .activity, evidenceTier: .tier1,
              optimalLow: 10_000, optimalHigh: nil,
              higherIsBetter: true,
              description: "Average daily steps over the last 30 days.",
              longevityContext: "10k steps/day associates with ~50% lower all-cause mortality vs 4k (Paluch et al., Lancet 2022). More is better — no upper penalty."),

        .init(id: "zone2_minutes", displayName: "Zone 2 / Week", unit: "min/wk",
              category: .activity, evidenceTier: .tier1,
              optimalLow: 180, optimalHigh: nil,
              higherIsBetter: true,
              description: "Minutes at 60–70% max HR per week.",
              longevityContext: "Zone 2 training is the primary driver of mitochondrial biogenesis and VO₂ Max improvements. Research (Attia, San Millán) supports 180+ min/week."),

        .init(id: "vigorous_minutes", displayName: "Vigorous / Week", unit: "min/wk",
              category: .activity, evidenceTier: .tier1,
              optimalLow: 20, optimalHigh: 30,
              higherIsBetter: true,
              description: "Minutes above 80% max HR per week.",
              longevityContext: "High-intensity intervals extend the VO₂ Max ceiling and improve insulin sensitivity beyond what Zone 2 alone achieves."),

        .init(id: "strength_sessions", displayName: "Strength Sessions", unit: "sessions/wk",
              category: .activity, evidenceTier: .tier1,
              optimalLow: 3, optimalHigh: nil,
              higherIsBetter: true,
              description: "Resistance training sessions per week.",
              longevityContext: "Muscle mass and strength are independent predictors of all-cause mortality. 3+ sessions/week significantly reduces risk of falls and metabolic disease."),

        .init(id: "training_load", displayName: "Training Load", unit: "AU/wk",
              category: .activity, evidenceTier: .tier2,
              optimalLow: nil, optimalHigh: nil,
              higherIsBetter: true,
              description: "Aggregate training stress from the last 7 days (HR × duration).",
              longevityContext: "Helps identify load/recovery imbalances. Contextualises recovery score — sustained high load with low recovery signals overtraining."),

        .init(id: "stand_hours", displayName: "Stand Hours", unit: "hrs/day",
              category: .activity, evidenceTier: .tier2,
              optimalLow: 12, optimalHigh: nil,
              higherIsBetter: true,
              description: "Average daily hours in which you stood for at least 1 minute (Apple Watch Stand ring). 30-day average.",
              longevityContext: "Prolonged sitting is an independent risk factor even in otherwise active individuals. Breaking sedentary time every hour improves postprandial glucose, endothelial function, and NEAT. 12+ stand hours/day = full ring completion."),

        // MARK: - Body Composition
        .init(id: "body_weight_trend", displayName: "Weight Trend", unit: "kg",
              category: .bodyComposition, evidenceTier: .tier2,
              optimalLow: nil, optimalHigh: nil,
              higherIsBetter: false,
              description: "Body weight — trend over 30 days is more meaningful than absolute value.",
              longevityContext: "Stable weight within a healthy range is associated with better longevity outcomes. Unintentional weight loss is a key mortality risk signal."),

        .init(id: "bmi", displayName: "BMI", unit: "kg/m²",
              category: .bodyComposition, evidenceTier: .tier2,
              optimalLow: 20, optimalHigh: 24,
              higherIsBetter: false,
              description: "Body mass index. A crude proxy — body fat % is more informative.",
              longevityContext: "Optimal longevity-associated BMI is 20–24. Above 25 associates with progressively higher mortality, particularly for cardiovascular disease."),

        // MARK: - Stress & Recovery
        .init(id: "mindful_minutes", displayName: "Mindful Minutes", unit: "min/day",
              category: .stressRecovery, evidenceTier: .tier2,
              optimalLow: 10, optimalHigh: nil,
              higherIsBetter: true,
              description: "Daily meditation or mindfulness practice.",
              longevityContext: "Consistent mindfulness practice reduces cortisol, improves HRV, and is associated with reduced inflammatory markers."),

        .init(id: "daylight_exposure", displayName: "Daylight Exposure", unit: "min/day",
              category: .stressRecovery, evidenceTier: .tier2,
              optimalLow: 30, optimalHigh: nil,
              higherIsBetter: true,
              description: "Minutes of outdoor light exposure per day.",
              longevityContext: "Morning daylight anchors the circadian clock, improving sleep quality, mood, and metabolic health."),

        .init(id: "wrist_temp", displayName: "Wrist Temperature", unit: "°C deviation",
              category: .stressRecovery, evidenceTier: .tier3,
              optimalLow: -0.3, optimalHigh: 0.3,
              higherIsBetter: false,
              description: "Deviation from personal wrist temperature baseline during sleep.",
              longevityContext: "Elevation signals illness, immune activity, or hormonal changes. Useful as an early warning signal rather than a direct longevity metric."),
    ]

    static func definition(for id: String) -> MetricDefinition? {
        all.first { $0.id == id }
    }
}

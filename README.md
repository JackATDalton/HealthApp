# Vitalia

A personal iOS longevity app that reads Apple Watch and HealthKit data, scores it against evidence-based optimal ranges, and uses the Claude API to generate on-demand personalised longevity plans.

Built for iOS 17+ with Swift 6, SwiftUI, SwiftData, and zero external dependencies.

---

## What it does

- **Dashboard** — syncs HealthKit on open and shows every tracked metric colour-coded against its optimal range
- **Recovery Score** — a daily 0–100 readiness score computed from last night's biometrics (HRV, RHR, sleep quality, sleep debt, respiratory rate, SpO₂, wrist temperature), each relative to your personal 30-day baseline
- **Longevity Score** — an evidence-weighted aggregate across all tracked metrics; Tier 1 metrics (strongest mortality evidence) carry 3× the weight of Tier 3
- **Historical charts** — per-metric history views with W / M / 6M / Y / All time ranges, querying HealthKit directly
- **Longevity plan** — tap "Generate Plan" and Claude produces a ranked, evidence-citing action plan based on your actual data; streams live
- **Focus metric** — Claude picks the single highest-leverage metric to concentrate on; persists on the dashboard between plan generations
- **Passive progress** — no manual logging; Claude reads your HealthKit history to recap what's changed since the last plan

---

## Metrics tracked

### Cardiovascular
| Metric | Optimal | Tier |
|---|---|---|
| VO₂ Max | ≥ 55 mL/kg/min (Apple Watch +3.5 correction) | 1 |
| Resting Heart Rate | 45–50 bpm | 1 |
| HRV | Long-term trend vs all-time personal baseline | 1 |
| Blood Oxygen (SpO₂) | 97–100% overnight minimum | 1 |
| Systolic Blood Pressure | 100–120 mmHg | 1 |
| Walking Heart Rate | ≤ 70 bpm | 2 |
| Cardio Recovery | ≥ 20 bpm/min drop | 2 |

### Sleep
| Metric | Optimal | Tier |
|---|---|---|
| Sleep Duration | 7–8.5 hours | 1 |
| Sleep Efficiency | ≥ 90% | 1 |
| Deep Sleep | ≥ 13% of night | 1 |
| REM Sleep | 20–25% of night | 1 |
| Awake During Night | ≤ 8% | 1 |
| 5-Day Sleep Debt | ≤ 30 min cumulative deficit | 1 |
| Sleep Consistency | ≤ 20 min bedtime variance | 2 |
| Respiratory Rate | 12–15 breaths/min (asymmetric — only elevation penalised) | 2 |

### Activity
| Metric | Optimal | Tier |
|---|---|---|
| Daily Steps | ≥ 10,000/day | 1 |
| Zone 2 Minutes | ≥ 180 min/week | 1 |
| Vigorous Minutes | ≥ 75 min/week (WHO guideline) | 1 |
| Strength Sessions | ≥ 3 sessions/week | 1 |
| Training Load | Contextual (no fixed range) | 2 |

### Body Composition
| Metric | Optimal | Tier |
|---|---|---|
| BMI | 20–24 kg/m² | 2 |
| Weight Stability | ≤ 5% change vs 6 months ago | 2 |

### Stress & Recovery
| Metric | Optimal | Tier |
|---|---|---|
| Mindful Minutes | ≥ 10 min/day | 2 |
| Daylight Exposure | ≥ 30 min/day | 2 |
| Wrist Temperature | ≤ 0.3°C deviation from baseline | 3 |

---

## Scoring

### Individual metrics

Each metric is converted to a 0–100 score using a non-linear piecewise decay based on deviation from its optimal range:

| Deviation | Score |
|---|---|
| 0–10% | 100 → 80 |
| 10–30% | 80 → 50 |
| 30–60% | 50 → 20 |
| 60%+ | 20 → 0 |

### Recovery Score

Seven overnight inputs, each weighted and scored relative to your personal 30-day baseline:

| Input | Weight |
|---|---|
| HRV | 35% |
| Resting Heart Rate | 25% |
| Sleep Quality | 20% |
| Sleep Debt | 10% |
| Respiratory Rate | 5% |
| SpO₂ | 3% |
| Wrist Temperature | 2% |

Weights redistribute if an input is unavailable. Score is marked **Incomplete** (not estimated) if HRV, RHR, and sleep quality are all missing.

### Longevity Score

Evidence-weighted average across all enabled metrics with data:

```
Longevity Score = evidence-weighted average

Tier 1 weight = 3×
Tier 2 weight = 2×
Tier 3 weight = 1×
```

---

## Architecture

```
iOS App (SwiftUI + Swift 6)
├── HealthKit Layer
│   ├── HealthKitPermissionsManager   — request/check authorisations
│   ├── HealthKitMetricsCollector     — fetch & aggregate all tracked metrics
│   └── HealthKitHistoryFetcher       — per-metric historical data (W/M/6M/Y/All)
├── Analysis Layer
│   ├── MetricEvaluator               — value → 0–100 score + status
│   ├── RecoveryScoreCalculator       — 7-input daily recovery score
│   └── LongevityScoreCalculator      — evidence-weighted aggregate score
├── Claude Layer
│   ├── PromptBuilder                 — structured health snapshot + user profile
│   ├── ClaudeAPIClient               — Anthropic REST API with SSE streaming
│   └── ResponseParser                — parse + store structured plan
├── UI Layer
│   ├── DashboardView                 — metric grid, recovery + longevity cards
│   ├── RecoveryDetailView            — score breakdown, 30-day trend, component drill-down
│   ├── LongevityDetailView           — formula breakdown, metric list worst→best
│   ├── MetricDetailView              — history chart, optimal range, evidence context
│   ├── PlanView                      — live-streamed longevity plan
│   └── SettingsView                  — API key, metric enable/disable, profile
└── Persistence
    ├── SwiftData                     — plans, user profile, metric config
    └── Keychain                      — Claude API key
```

---

## Setup

1. Clone the repo and open `Vitalia.xcodeproj`
2. Set your development team in project settings
3. Build and run on a physical device (HealthKit requires real hardware)
4. On first launch, grant HealthKit permissions and enter your Claude API key in Settings

A Claude API key is required for plan generation. Get one at [console.anthropic.com](https://console.anthropic.com). The app uses `claude-sonnet-4-6` by default.

---

## Privacy

- All health data stays on-device — nothing is sent to any server except Anthropic's API
- Only metric summaries are sent to Claude (no raw time-series data)
- You can preview the exact prompt before any API call
- API key stored in iOS Keychain
- No analytics, no crash reporting, no third-party SDKs

---

## Requirements

- iOS 17+
- Apple Watch (Series 4+ for HRV; Series 8+ for wrist temperature)
- Xcode 15+

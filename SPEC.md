# Longevity AI — App Specification

> Personal iOS app that reads Apple Watch / HealthKit data, analyses it against maximally ambitious longevity-optimised ranges, computes a daily recovery score, and uses the Claude API to generate on-demand personalised longevity plans.

---

## 1. Vision

A private, single-user iOS app that acts as a personal longevity coach. It pulls real health data from Apple Watch and HealthKit, benchmarks each metric against evidence-based *optimal* ranges (not government minimums — what the research actually suggests maximises lifespan and healthspan), computes a daily recovery score from overnight biometrics, and calls Claude on demand to produce a prioritised, plain-English action plan. Progress is tracked passively through HealthKit — no manual habit logging.

---

## 2. Core User Flow

```
First Launch
  → Pull user profile from HealthKit (age, sex, height, weight)
  → User fills any gaps (fitness background, primary goal)
  → User reviews metric list, disables any they don't care about
  → Set custom range overrides if desired (optional)

Daily Use
  → Open App
  → Dashboard auto-syncs latest HealthKit data
  → View today's Recovery Score (computed from last night's biometrics)
  → View metrics colour-coded (optimal / borderline / out of range)
  → View overall Longevity Score (aggregate of all enabled metrics)
  → If data has shifted meaningfully since last plan → nudge to re-generate
  → Tap "Generate Plan" when desired
  → Claude response streams in live → ranked longevity plan
  → Plan references passive HealthKit signals for progress (sleep, activity rings, etc.)
```

---

## 3. Health Metrics to Track

Metrics are weighted by **evidence tier** — how strongly peer-reviewed longevity research supports each metric as a predictor of all-cause mortality and healthspan. Claude uses these weights when prioritising.

### Evidence Tiers
- **Tier 1 — Strong** (multiple large RCTs / cohort studies, direct longevity association)
- **Tier 2 — Moderate** (observational evidence, mechanistic support, expert consensus)
- **Tier 3 — Emerging** (promising but limited direct longevity data)

---

### Cardiovascular
| Metric | Source | Longevity-Optimal Range | Evidence Tier |
|---|---|---|---|
| VO₂ Max | Apple Watch (est.) | >55 mL/kg/min adjusted for AW underestimation¹ | Tier 1 |
| Resting Heart Rate | Apple Watch | 40–55 bpm | Tier 1 |
| Heart Rate Variability (HRV) | Apple Watch | Top quartile for age/sex (higher = better) | Tier 1 |
| Blood Oxygen (SpO₂) | Apple Watch | 97–100% | Tier 2 |
| Walking Heart Rate Avg | Apple Watch | <70 bpm (trending downward) | Tier 2 |
| Cardio Recovery (1-min HR drop post-exercise) | Apple Watch | >20 bpm drop | Tier 2 |

> **¹ VO₂ Max Apple Watch adjustment:** Apple Watch consistently underestimates VO₂ Max vs lab testing by ~3–5 mL/kg/min on average (varies by individual and workout type). The app will display the raw Apple Watch figure but note this discrepancy, apply a +3.5 mL/kg/min correction factor when evaluating against optimal ranges, and remind the user that a lab/metabolic test is the gold standard. Research (Kokkinos, Attia, JAMA 2022): elite VO₂ Max (top 2.5%) associates with ~5× lower all-cause mortality vs bottom quartile.

---

### Sleep
| Metric | Source | Longevity-Optimal Range | Evidence Tier |
|---|---|---|---|
| Total Sleep Duration | Apple Watch | 7–8.5 hours (not more, not less) | Tier 1 |
| Sleep Efficiency | HealthKit | >90% | Tier 1 |
| Deep Sleep % | Apple Watch | >20% of total sleep | Tier 1 |
| REM Sleep % | Apple Watch | 20–25% of total sleep | Tier 1 |
| Sleep Consistency (bedtime variance) | HealthKit | <20 min variance (circadian anchor) | Tier 2 |
| Respiratory Rate during sleep | Apple Watch | 12–15 breaths/min | Tier 2 |

> **Note on sleep duration:** The U-curve is real — both <6 hrs and >9 hrs associate with mortality. Optimal is 7–8.5 hrs, not "as much as possible."

---

### Activity & Movement
| Metric | Source | Longevity-Optimal Range | Evidence Tier |
|---|---|---|---|
| VO₂ Max (see Cardiovascular) | — | — | — |
| Daily Steps | Apple Watch | 10,000–12,000 (diminishing returns above ~12k) | Tier 1 |
| Exercise Minutes (Zone 2 cardio) | Apple Watch | 180+ min/week | Tier 1 |
| Vigorous Activity Minutes | Apple Watch | 20–30 min/week HIIT equivalent | Tier 1 |
| Stand / Non-sedentary hours | Apple Watch | <8 hrs sitting; 12+ active hours | Tier 2 |
| Resting Energy (TDEE trend) | HealthKit | Stable or improving metabolic rate | Tier 3 |

> **Zone 2 framing:** Research (Attia, Iñigo San Millán) supports ~80% of training volume at low intensity (conversational pace, nose-breathing). Vigorous minutes cover the remaining high-intensity work shown to extend VO₂ Max ceiling.

---

### Body Composition
| Metric | Source | Longevity-Optimal Range | Evidence Tier |
|---|---|---|---|
| Body Weight (relative trend) | Health app | Stable within healthy range | Tier 2 |
| BMI | Health app | 20–24 (limitation: not body-comp aware) | Tier 2 |

> **Note:** BMI is a crude proxy. If the user has body fat % data (from a connected scale via HealthKit), that is preferred. Optimal body fat: ~12–18% men, ~18–25% women for longevity.

---

### Stress & Recovery
| Metric | Source | Longevity-Optimal Range | Evidence Tier |
|---|---|---|---|
| Mindful Minutes | HealthKit | >10 min/day | Tier 2 |
| Wrist Temperature trend | Apple Watch (Series 8+) | Stable (spikes = illness/stress signal) | Tier 3 |
| Time in Daylight | HealthKit | >30 min/day | Tier 2 |

---

## 4. Recovery Score

Apple's native app does not surface a useful daily readiness/recovery signal. This app computes one from overnight Apple Watch data, inspired by Whoop's approach.

### How it's calculated

The Recovery Score is a **0–100 daily score** derived from four overnight inputs, each weighted by their evidence for reflecting autonomic recovery:

| Input | Weight | What "good" looks like |
|---|---|---|
| HRV (overnight average vs your 30-day baseline) | 40% | At or above personal baseline |
| Resting Heart Rate (overnight low vs your 30-day baseline) | 30% | At or below personal baseline |
| Sleep Quality (efficiency × deep% × duration vs optimal) | 20% | >90% efficiency, >20% deep, 7–8.5 hrs |
| Respiratory Rate (vs personal baseline) | 10% | Stable; elevated RR signals illness/stress |

**Key principle:** scores are relative to *your own baselines*, not population averages. A trained athlete with RHR of 42 and a beginner with RHR of 62 both score well when they're near their own normal.

**Baseline initialisation:** a minimum of 14 days of Apple Watch data is needed before the Recovery Score is meaningful. Until then, the dashboard shows a "Building your baseline" state with a progress indicator. The app can use existing historical HealthKit data (not just data collected after install) to satisfy this requirement immediately for most users.

### Score bands

| Score | Label | Meaning |
|---|---|---|
| 85–100 | Recovered | Push hard today — good day for high-intensity training |
| 65–84 | Moderate | Normal training fine; avoid max-effort sessions |
| 40–64 | Fatigued | Prioritise Zone 2 or active recovery; investigate sleep |
| 0–39 | Under-recovered | Rest day recommended; something is off (illness, stress, poor sleep) |

### Dashboard display

- Large, prominent score on the dashboard — the first thing you see each morning
- Colour-coded ring or arc (green / amber / orange / red)
- Tap to see the breakdown: which of the 4 inputs is dragging the score and why
- 30-day trend chart to see recovery patterns (e.g. cumulative fatigue building across a training block)

### Recovery score in the longevity plan

When generating a plan, Claude receives:
- Today's recovery score + which inputs drove it
- 7-day recovery score history
- This allows Claude to adjust recommendations: e.g. "your recovery has been below 65 for 5 of the last 7 days — your current training load may be exceeding your recovery capacity"

---

## 5. User Profile & Onboarding

### Auto-pulled from HealthKit (with user permission)
- Date of birth → age
- Biological sex
- Height
- Body weight (latest reading)
- Blood type (if stored)

### User-provided (short onboarding form, skippable fields)
- Fitness background (sedentary / moderately active / trained athlete) — calibrates VO₂ Max targets and recovery baselines
- Primary goal (live as long as possible / maximise energy & performance / disease prevention)
- Any metrics to disable upfront

### Metric management
- Any metric can be **disabled** from the dashboard and excluded from Claude's analysis
- Disabled metrics can be re-enabled at any time from Settings
- User can set a **custom target range** per metric (overrides the default longevity-optimal range)
- Custom ranges show a note indicating they diverge from the research-backed default

---

## 6. Claude API Integration

### What Claude receives
A structured JSON-like prompt containing:
- User profile: age, sex, fitness background, primary goal
- Today's Recovery Score + breakdown (HRV, RHR, sleep quality, respiratory rate contributions)
- 7-day recovery score history
- Per metric (enabled only): name, current value, 7-day average, 30-day trend direction, longevity-optimal range, user's custom range (if set), deviation score, evidence tier
- Metrics sorted by: `(deviation from optimal) × (evidence tier weight)`
- Previous plan summary (for continuity — "last time we focused on X")
- Recent HealthKit signals used as passive progress indicators (sleep duration last 7 days, exercise minutes last 7 days, active energy trend, steps)

### What Claude returns
1. **Status Summary** — 2–3 sentences on overall longevity picture, honest and direct
2. **Priority Issues** — top 3–5 metrics to address, ranked by evidence-weighted impact; each with:
   - Why it matters for longevity (cite specific mechanisms/research)
   - How far from optimal and what closing that gap is worth
3. **Action Plan** — per priority issue: 2–3 specific, concrete actions (not generic advice). Referenced against the user's actual data. Tagged `[daily]`, `[weekly]`, `[one-time]`
4. **Passive Progress** — what HealthKit data already shows about adherence since last plan (no manual entry required)
5. **Wins** — metrics at or above optimal range, acknowledged briefly
6. **Focus for this period** — single highest-leverage metric to concentrate on before generating the next plan

### Prompt design principles
- Longevity frameworks explicitly included in system prompt: Peter Attia (outlive framework), Bryan Johnson (Blueprint), Valter Longo (longevity diet/fasting research), hallmarks of aging literature
- Ranges are described as "optimal for longevity" not "healthy" — Claude should distinguish these clearly
- Tone: direct, evidence-citing, no hedging for the sake of hedging — this is a personal tool, not a medical product
- Claude response is streamed — UI renders text progressively as it arrives
- Model: claude-sonnet-4-6 (default) — configurable to claude-opus-4-6 for deeper analysis
- Plans stored locally and versioned (SwiftData)

---

## 7. Passive Progress Tracking

No manual habit logging. Progress is inferred from HealthKit data that updates automatically:

| What to track | HealthKit source | How used in next plan |
|---|---|---|
| Sleep duration & quality | Apple Watch sleep data | Claude notes if sleep has improved since last plan |
| Exercise minutes / type | Apple Fitness workouts | Claude notes training volume vs target |
| Active energy | Apple Watch | Trend vs baseline |
| Steps | Apple Watch | vs 10–12k target |
| Mindful minutes | HealthKit mindfulness | vs daily target |
| HRV trend | Apple Watch | Recovery signal |

When generating a new plan, Claude opens with a brief "since your last plan" recap based purely on this passive data.

---

## 8. App Architecture

```
iOS App (SwiftUI)
├── HealthKit Layer
│   ├── PermissionsManager       — request/check HK authorisations
│   ├── ProfileImporter          — pull age, sex, height, weight from HK
│   ├── MetricsCollector         — fetch & aggregate all tracked metrics
│   └── PassiveProgressReader    — fetch sleep, workout, activity data for plan context
├── Analysis Layer
│   ├── MetricEvaluator          — compare values against optimal/custom ranges
│   ├── TrendAnalyser            — 7-day / 30-day trend + direction
│   ├── EvidenceWeighter         — apply tier weights to deviation scores
│   ├── PriorityRanker           — final priority sort for Claude prompt
│   ├── RecoveryScoreCalculator  — compute daily 0–100 score from HRV/RHR/sleep/RespRate vs personal baselines
│   └── LongevityScoreCalculator — non-linear aggregate: weighted average with Tier 1 outlier penalty (single bad Tier 1 metric caps overall score)
├── Claude Layer
│   ├── PromptBuilder            — assemble structured health snapshot + user profile
│   ├── ClaudeAPIClient          — Anthropic REST API with SSE streaming
│   └── ResponseParser           — parse + store structured plan
├── UI Layer
│   ├── DashboardView            — metric cards, colour-coded, disable toggle
│   ├── MetricDetailView         — 30-day trend chart, optimal range, evidence context
│   ├── PlanView                 — current longevity plan (scrollable, section-based)
│   ├── PlanHistoryView          — past plans timeline
│   └── SettingsView             — API key, model, user profile, metric overrides
└── Persistence Layer
    ├── SwiftData                — plans, user profile, metric config (enabled/disabled, custom ranges)
    └── Keychain                 — Claude API key
```

---

## 9. UI / UX Design Principles

- **Dark mode first** — longevity/performance aesthetic
- **Dashboard** — metric cards colour-coded: green (optimal), amber (borderline), red (out of range), grey (disabled)
- **Evidence tier visible** — small indicator on each card so user understands signal strength
- **One-tap plan generation** — prominent "Analyse & Plan" CTA, disabled if data is very stale
- **Plan as readable document** — scannable sections, not bullet soup
- **Passive progress, no manual logging** — the app reads your data, you don't feed it data
- **Transparency** — "Preview what's sent to Claude" before each API call
- **No clutter** — no social, no gamification, no streaks, no push to engage more

---

## 10. Screens

1. **Dashboard** — Recovery Score (large, top), Longevity Score, metric cards grid, re-plan nudge banner (when applicable), "Generate Plan" CTA, last-synced timestamp
2. **Recovery Detail** — today's score breakdown (HRV / RHR / sleep / resp. rate contributions), 30-day recovery trend chart
3. **Metric Detail** — 30-day trend chart, current vs optimal range visualisation, evidence tier explanation, enable/disable toggle, custom range editor
4. **Plan View** — current AI plan streamed live on generation; sections: Status Summary / Recovery Context / Priority Issues / Action Plan / Passive Progress / Wins / Focus
5. **Plan History** — chronological list of past plans, tap to read any previous plan
6. **Onboarding / Profile** — HealthKit import + fitness background + primary goal; accessible again from Settings
7. **Settings** — Claude API key (Keychain-backed), model selector, units (metric/imperial), re-plan nudge toggle, reset options

---

## 11. Notifications

Minimal, non-intrusive:
- Optional: nudge to generate a new plan when key metrics have shifted meaningfully since last plan (configurable threshold, default: 3+ metrics have changed by >10% of their range)
- Optional: weekly reminder if no plan has been generated in 7+ days
- No daily pings, no streak alerts, no engagement-bait notifications

---

## 12. Data Privacy

- All health data stays on-device — never sent to any server other than Anthropic's Claude API
- Only structured metric *summaries* sent (no raw time-series data)
- User can preview the exact prompt before any API call
- Claude API key stored in iOS Keychain, never in app storage or logs
- No analytics, no crash reporting, no third-party SDKs

---

## 13. Out of Scope (v1)

- Third-party wearable integrations (Oura, Whoop, Garmin) — HealthKit only
- Lab results / blood panel integration — manual entry in v2
- Multiple user profiles
- Android / web
- Subscription / monetisation
- Plan export or sharing
- Manual habit logging / check-ins

---

## 14. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Swift 6 | Native iOS performance |
| UI | SwiftUI | Modern, declarative |
| Health data | HealthKit | Direct Apple Watch + Health app access |
| AI | Anthropic Claude API (REST) | claude-sonnet-4-6 default, claude-opus-4-6 option |
| Persistence | SwiftData | Simple, native, no server |
| Secrets | iOS Keychain | Secure API key storage |
| Charts | Swift Charts | Native, no dependencies |
| Minimum iOS | iOS 17 | SwiftData + latest HealthKit sleep/workout APIs |

---

## 15. Resolved Design Decisions

| Decision | Resolution |
|---|---|
| Plan generation | On-demand only — user taps "Generate Plan" |
| Metric weighting | Weighted by evidence tier (Tier 1 > 2 > 3) × deviation from optimal |
| Optimal ranges | Maximally ambitious for longevity (research-backed, not government guidelines) |
| Custom ranges | Supported per metric; user's override shown alongside research default |
| User profile | Auto-imported from HealthKit where available; no medical conditions — fitness background + goal only |
| Habit tracking | No manual logging — progress inferred passively from HealthKit data |
| Metric suppression | Any metric can be disabled and excluded from analysis |
| Longevity score | Yes — non-linear aggregate: Tier 1 metric failures penalised disproportionately; a single critical Tier 1 outlier can cap the overall score |
| Re-plan nudge | Yes — app detects meaningful metric shifts and surfaces a banner prompt |
| Medical caveats | No conservative caveating — personal tool, direct recommendations |
| VO₂ Max calibration | Apple Watch underestimates by ~3.5 mL/kg/min; app applies correction factor and notes discrepancy |
| Claude streaming | Yes — response streams live using SSE |
| Recovery score | Yes — computed daily from HRV, RHR, sleep quality, respiratory rate vs personal baselines; 14-day minimum before score is shown (show "building baseline" state until then) |

---

## 16. Open Questions

1. **Recovery score weighting** — the 40/30/20/10 split (HRV/RHR/sleep/RespRate) is a starting point; fixed for now, revisit after real-world use
2. **Re-plan nudge threshold** — "3+ metrics changed by >10% of range" is an initial heuristic; tune after real data is available

---

*Draft v0.4 — 2026-03-28*

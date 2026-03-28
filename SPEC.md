# Longevity AI — App Specification

> Personal iOS app that reads Apple Watch / HealthKit data, analyses it against maximally ambitious longevity-optimised ranges, and uses the Claude API to generate on-demand personalised plans.

---

## 1. Vision

A private, single-user iOS app that acts as a personal longevity coach. It pulls real health data from Apple Watch and HealthKit, benchmarks each metric against evidence-based *optimal* ranges (not government minimums — what the research actually suggests maximises lifespan and healthspan), identifies gaps weighted by strength of evidence, and calls Claude on demand to produce a prioritised, plain-English action plan. Progress is tracked passively through HealthKit — no manual habit logging.

---

## 2. Core User Flow

```
First Launch
  → Pull user profile from HealthKit (age, sex, height, weight)
  → User fills any gaps + adds medical context (conditions, medications)
  → User reviews metric list, disables any they don't care about
  → Set custom range overrides if desired (optional)

Daily Use
  → Open App
  → Dashboard auto-syncs latest HealthKit data
  → View metrics colour-coded (optimal / borderline / out of range)
  → Tap "Generate Plan" when desired
  → Claude analyses gaps (weighted by evidence strength) → ranked longevity plan
  → Plan references passive HealthKit signals for progress (sleep, activity rings, etc.)
  → Re-generate when meaningful time has passed or data has changed
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
| VO₂ Max | Apple Watch | >55 mL/kg/min (elite; top 2% for age) | Tier 1 |
| Resting Heart Rate | Apple Watch | 40–55 bpm | Tier 1 |
| Heart Rate Variability (HRV) | Apple Watch | Top quartile for age/sex (higher = better) | Tier 1 |
| Blood Oxygen (SpO₂) | Apple Watch | 97–100% | Tier 2 |
| Walking Heart Rate Avg | Apple Watch | <70 bpm (trending downward) | Tier 2 |
| Cardio Recovery (1-min HR drop post-exercise) | Apple Watch | >20 bpm drop | Tier 2 |

> **Note on VO₂ Max:** Research (Kokkinos, Attia, JAMA 2022) shows the highest longevity benefit is in moving from low to moderate fitness, but elite-level VO₂ Max (top 2.5%) is associated with a ~5× reduction in all-cause mortality vs bottom quartile. Optimal target is therefore ambitious, not just "normal".

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

## 4. User Profile & Onboarding

### Auto-pulled from HealthKit (with user permission)
- Date of birth → age
- Biological sex
- Height
- Body weight (latest reading)
- Blood type (if stored)

### User-provided (short onboarding form, skippable fields)
- Medical conditions relevant to longevity (e.g. hypertension, T2D, family history of CVD/cancer)
- Current medications (affects interpretation — e.g. beta-blockers suppress HRV/RHR)
- Fitness background (sedentary / moderately active / trained athlete) — helps calibrate VO₂ Max targets
- Primary goal (live as long as possible / maximise energy & performance / disease prevention)
- Any metrics to disable upfront

### Metric management
- Any metric can be **disabled** from the dashboard and excluded from Claude's analysis
- Disabled metrics can be re-enabled at any time from Settings
- User can set a **custom target range** per metric (overrides the default longevity-optimal range)
- Custom ranges show a note indicating they diverge from the research-backed default

---

## 5. Claude API Integration

### What Claude receives
A structured JSON-like prompt containing:
- User profile: age, sex, fitness background, relevant medical context, active medications
- Per metric (enabled only): name, current value, 7-day average, 30-day trend direction, longevity-optimal range, user's custom range (if set), deviation score, evidence tier
- Metrics sorted by: `(deviation from optimal) × (evidence tier weight)`
- Previous plan summary (for continuity — "last time we focused on X")
- Recent HealthKit signals used as passive progress indicators (e.g. sleep duration last 7 days, exercise minutes last 7 days, active energy trend)

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
- Ranges are described as "optimal for longevity" not "healthy" — Claude should distinguish these
- User's medical context used to caveat or adjust recommendations appropriately
- Tone: direct, evidence-citing, no hedging for the sake of hedging
- Model: Claude claude-sonnet-4-6 (default) — configurable to claude-opus-4-6 for deeper analysis
- Plans stored locally and versioned

---

## 6. Passive Progress Tracking

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

## 7. App Architecture

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
│   └── PriorityRanker           — final priority sort for Claude prompt
├── Claude Layer
│   ├── PromptBuilder            — assemble structured health snapshot + user profile
│   ├── ClaudeAPIClient          — Anthropic REST API (streaming preferred)
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

## 8. UI / UX Design Principles

- **Dark mode first** — longevity/performance aesthetic
- **Dashboard** — metric cards colour-coded: green (optimal), amber (borderline), red (out of range), grey (disabled)
- **Evidence tier visible** — small indicator on each card so user understands signal strength
- **One-tap plan generation** — prominent "Analyse & Plan" CTA, disabled if data is very stale
- **Plan as readable document** — scannable sections, not bullet soup
- **Passive progress, no manual logging** — the app reads your data, you don't feed it data
- **Transparency** — "Preview what's sent to Claude" before each API call
- **No clutter** — no social, no gamification, no streaks, no push to engage more

---

## 9. Screens

1. **Dashboard** — metric cards grid, overall longevity score, last-synced timestamp, "Generate Plan" CTA
2. **Metric Detail** — 30-day trend chart, current vs optimal range visualisation, evidence tier explanation, enable/disable toggle, custom range editor
3. **Plan View** — current AI plan: Status Summary / Priority Issues / Action Plan / Passive Progress / Wins / Focus
4. **Plan History** — chronological list of past plans, tap to read any previous plan
5. **Onboarding / Profile** — HealthKit import + manual context fields, accessible again from Settings
6. **Settings** — Claude API key (Keychain-backed), model selector, units (metric/imperial), reset options

---

## 10. Notifications

Minimal, non-intrusive:
- Optional: weekly nudge to generate a new plan if none has been generated in 7+ days
- No daily pings, no streak alerts, no engagement-bait notifications

---

## 11. Data Privacy

- All health data stays on-device — never sent to any server other than Anthropic's Claude API
- Only structured metric *summaries* sent (no raw time-series data)
- User can preview the exact prompt before any API call
- Claude API key stored in iOS Keychain, never in app storage or logs
- No analytics, no crash reporting, no third-party SDKs

---

## 12. Out of Scope (v1)

- Third-party wearable integrations (Oura, Whoop, Garmin) — HealthKit only
- Lab results / blood panel integration — manual entry in v2
- Multiple user profiles
- Android / web
- Subscription / monetisation
- Plan export or sharing
- Manual habit logging / check-ins

---

## 13. Tech Stack

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

## 14. Resolved Design Decisions

| Decision | Resolution |
|---|---|
| Plan generation | On-demand only — user taps "Generate Plan" |
| Metric weighting | Weighted by evidence tier (Tier 1 > 2 > 3) × deviation from optimal |
| Optimal ranges | Maximally ambitious for longevity (research-backed, not government guidelines) |
| Custom ranges | Supported per metric; user's override shown alongside research default |
| User profile | Auto-imported from HealthKit where available; manual supplement for medical context |
| Habit tracking | No manual logging — progress inferred passively from HealthKit data |
| Metric suppression | Any metric can be disabled and excluded from analysis |

---

## 15. Open Questions

1. **Longevity score** — single aggregate score on the dashboard: useful motivator or reductive/misleading?
2. **Plan regeneration signal** — should the app suggest "your data has changed enough to re-plan" or leave it entirely up to the user?
3. **Medical caveats** — how conservatively should Claude caveat recommendations given user-reported medical conditions? (e.g. HRV targets may differ significantly with known arrhythmia)
4. **VO₂ Max target calibration** — Apple Watch VO₂ Max tends to underestimate vs lab testing; should the app note this discrepancy and adjust targets?
5. **Streaming vs batch** — stream Claude's response word-by-word (feels live) or show full response at once?

---

*Draft v0.2 — 2026-03-28*

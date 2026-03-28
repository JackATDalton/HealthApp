# Longevity AI — App Specification

> Personal iOS app that reads Apple Watch / HealthKit data, analyses it against optimal longevity ranges, and uses the Claude API to generate personalised, actionable plans.

---

## 1. Vision

A private, single-user iOS app that acts as a personal longevity coach. It pulls real health data from Apple Watch and HealthKit, benchmarks each metric against evidence-based optimal ranges, identifies gaps, and calls Claude to produce a prioritised, plain-English action plan updated on a cadence you choose.

---

## 2. Core User Flow

```
Open App
  → Sync latest HealthKit data
  → View dashboard: metrics colour-coded (optimal / suboptimal / out of range)
  → Tap "Generate Plan" (or auto-generate on schedule)
  → Claude analyses gaps and produces a ranked longevity plan
  → Plan broken into daily / weekly habits with expected impact
  → Track adherence over time
  → Re-analyse as new data arrives
```

---

## 3. Health Metrics to Track

### Cardiovascular
| Metric | Source | Optimal Range (longevity) |
|---|---|---|
| Resting Heart Rate | Apple Watch | 45–60 bpm |
| Heart Rate Variability (HRV) | Apple Watch | Age-adjusted; higher = better |
| VO₂ Max | Apple Watch | >40 mL/kg/min (age-adjusted) |
| Blood Oxygen (SpO₂) | Apple Watch | 95–100% |
| Cardio Fitness trend | HealthKit | Improving or stable |

### Sleep
| Metric | Source | Optimal Range |
|---|---|---|
| Total Sleep Duration | Apple Watch / Health | 7–9 hours |
| Deep Sleep % | Apple Watch | >20% of total |
| REM Sleep % | Apple Watch | 20–25% of total |
| Sleep Consistency (bedtime variance) | HealthKit | <30 min variance |
| Sleep Efficiency | HealthKit | >85% |

### Activity & Movement
| Metric | Source | Optimal Range |
|---|---|---|
| Daily Steps | Apple Watch | 8,000–12,000 |
| Active Energy (kcal) | Apple Watch | Goal-relative |
| Exercise Minutes | Apple Watch | 150+ min/week moderate |
| Stand Hours | Apple Watch | 12/day |
| Walking/Running Pace | HealthKit | Trend improving |

### Metabolic (via manual entry or connected devices)
| Metric | Source | Notes |
|---|---|---|
| Resting Energy | HealthKit | Tracked passively |
| Body Weight / BMI | Health app / manual | Optional |
| Blood Glucose trends | Health app (CGM) | Optional integration |

### Stress & Recovery
| Metric | Source | Optimal Range |
|---|---|---|
| Mindful Minutes | HealthKit | >10 min/day |
| Respiratory Rate | Apple Watch | 12–18 breaths/min |
| Walking Heart Rate Avg | Apple Watch | Lower trend = better |

---

## 4. Claude API Integration

### What Claude receives
A structured prompt containing:
- User's age / sex (stored locally, user-provided)
- Snapshot of each metric: current value, 7-day average, 30-day trend, optimal range, deviation
- Metrics ranked by how far outside optimal range they are
- Any previous plan for continuity

### What Claude returns
1. **Summary** — 2–3 sentence plain-English overview of current health status
2. **Priority Issues** — ranked list of the top 3–5 metrics needing attention, with brief explanation of why they matter for longevity
3. **Action Plan** — per issue: specific, actionable habit recommendations (not generic advice), each tagged with `[daily]`, `[weekly]`, or `[one-time]`
4. **Wins** — metrics that are in or above optimal range (positive reinforcement)
5. **Focus metric of the week** — single metric to concentrate on

### Prompt strategy
- Use Claude claude-sonnet-4-6 (or configurable)
- Include longevity-specific context (Bryan Johnson Blueprint ranges, Peter Attia frameworks, etc. referenced but not required)
- Keep prompts deterministic: same data → comparable output
- Plans stored locally and versioned so you can see how recommendations evolve

---

## 5. App Architecture

```
iOS App (SwiftUI)
├── HealthKit Layer
│   ├── PermissionsManager       — request/check HK authorisations
│   ├── MetricsCollector         — fetch & aggregate metrics
│   └── SyncScheduler            — background refresh (daily)
├── Analysis Layer
│   ├── MetricEvaluator          — compare values against optimal ranges
│   ├── TrendAnalyser            — 7-day / 30-day trend calculation
│   └── PriorityRanker           — score metrics by deviation severity
├── Claude Layer
│   ├── PromptBuilder            — assemble structured health snapshot
│   ├── ClaudeAPIClient          — Anthropic REST API calls
│   └── ResponseParser           — parse + store structured plan
├── UI Layer
│   ├── DashboardView            — metric cards with colour coding
│   ├── MetricDetailView         — single metric deep-dive + trend chart
│   ├── PlanView                 — current longevity plan
│   ├── HistoryView              — past plans + metric trends
│   └── SettingsView             — API key, user profile, preferences
└── Persistence Layer
    ├── SwiftData / CoreData     — store plans, user profile, metric history
    └── Keychain                 — store Claude API key securely
```

---

## 6. UI / UX Design Principles

- **Dark mode first** — health/longevity aesthetic
- **Dashboard** — coloured metric cards: green (optimal), amber (borderline), red (out of range)
- **One-tap plan generation** — prominent "Analyse & Plan" button
- **Plan as readable document** — not a wall of bullet points; scannable sections
- **Progress tracking** — mark habits as done, see adherence streaks
- **No clutter** — single-user, no accounts, no social features

---

## 7. Data Privacy

- All health data stays on-device — never sent to any server other than Claude API
- Only the structured metric *summary* (no raw time-series data) is sent to Claude
- Claude API key stored in iOS Keychain
- No analytics, no crash reporting to third parties
- Option to review exactly what is sent to Claude before each API call

---

## 8. Screens

1. **Dashboard** — grid/list of all metric cards, overall "health score" indicator, last-updated timestamp, "Generate Plan" CTA
2. **Metric Detail** — chart of 30-day trend, current vs optimal range, what this metric means for longevity
3. **Plan View** — current AI-generated plan, sections: Summary / Priority Issues / Action Plan / Wins / Focus Metric
4. **Plan History** — timeline of past plans, diff view (what changed since last plan)
5. **Habit Tracker** — today's habits from the plan, check off completed items, streak counter
6. **Settings** — Claude API key, model selection, user profile (age/sex), plan generation schedule, units

---

## 9. Notifications

- Daily morning summary: "3 metrics need attention today"
- Plan generation reminder (configurable)
- Streak alerts: "You've hit your sleep target 5 days in a row"
- Weekly trend digest

---

## 10. Out of Scope (v1)

- Third-party integrations (Oura, Whoop, Garmin) — HealthKit only for now
- Lab results integration (blood panels) — manual entry possible in v2
- Multiple user profiles
- Android / web versions
- Subscription / monetisation
- Sharing or export of plans

---

## 11. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Swift 6 | Native iOS performance |
| UI | SwiftUI | Modern, declarative |
| Health data | HealthKit | Direct Apple Watch access |
| AI | Anthropic Claude API (REST) | Flexible, powerful reasoning |
| Persistence | SwiftData | Simple, native, no server |
| Secrets | iOS Keychain | Secure API key storage |
| Charts | Swift Charts | Native, no dependencies |
| Minimum iOS | iOS 17 | SwiftData + latest HealthKit APIs |

---

## 12. Open Questions (to resolve before building)

1. **Plan generation frequency** — on-demand only, or auto-generate daily/weekly?
2. **Metric weighting** — should some metrics (e.g. HRV, VO₂ Max) be weighted more heavily than others in the priority ranking?
3. **Optimal ranges** — use fixed published ranges, or let the user customise their own targets?
4. **Manual overrides** — can the user mark a metric as "not relevant" or suppress it from the plan?
5. **Habit carry-over** — do incomplete habits from yesterday's plan roll over?
6. **Claude model** — default to Sonnet for cost/speed, allow switching to Opus for more depth?
7. **Onboarding** — how much context does the user provide upfront (age, sex, goals, medical conditions)?

---

*Draft v0.1 — 2026-03-28*

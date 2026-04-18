# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

**No Makefile or build scripts.** Project uses XcodeGen — regenerate the Xcode project if `project.yml` changes:

```bash
xcodegen generate
open Vitalia.xcodeproj
```

Build and run via Xcode (Cmd+B / Cmd+R). **Physical device required** — HealthKit does not work in the simulator. iOS 17+, Xcode 16+.

Run tests:
```bash
xcodebuild -project Vitalia.xcodeproj -scheme VitaliaTests test
```

There are currently minimal unit tests (`VitaliaTests/RecoveryScoreTests.swift`). UI tests exist as a placeholder only.

## Architecture

Data flows in one direction through four layers:

```
HealthKit
  → HealthKitMetricsCollector (25+ concurrent async let queries)
  → [String: Double] snapshot (all metric values)
  → Analysis layer (RecoveryScoreCalculator, MetricEvaluator, LongevityScoreCalculator)
  → AppState (@Observable, @MainActor — the single source of truth for all UI)
  → SwiftUI views
  → SwiftData persistence (UserProfile, MetricConfig, DailySnapshot, LongevityPlan)
```

`AppState.sync()` is the orchestration entry point — it runs the full pipeline above in sequence.

### Key layers

**`Vitalia/HealthKit/`** — All HealthKit I/O. Each file has a focused responsibility:
- `HealthKitMetricsCollector` — fires all queries concurrently; returns the snapshot
- `HealthKitSleepAnalyser` — parses Apple Watch sleep stage data
- `HealthKitWorkoutAnalyser` — derives Zone 2 minutes, vigorous minutes, strength sessions from HR samples across the last 30 workouts
- `HealthKitHistoryFetcher` — per-metric historical time series for charts (W/M/6M/Y/All)

**`Vitalia/Analysis/`** — Pure scoring logic, no HealthKit or UI dependencies:
- `RecoveryScoreCalculator` — 7 overnight inputs → 0–100 daily readiness score. Weights: HRV 35%, RHR 25%, sleep quality 20%, sleep debt 10%, RR 5%, SpO₂ 3%, wrist temp 2%. All inputs scored relative to the user's personal 30-day baseline. Missing inputs have their weight redistributed proportionally.
- `MetricEvaluator` — single metric value + optimal range → 0–100 score using non-linear piecewise decay (0–10% deviation: 100→80, 10–30%: 80→50, 30–60%: 50→20, 60%+: 20→0).
- `LongevityScoreCalculator` — evidence-weighted average of all metric scores (Tier 1 = 3×, Tier 2 = 2×, Tier 3 = 1×). HRV is a special case: scored by comparing the 30-day average against the all-time average (long-term trend), not against absolute optimal ranges.

**`Vitalia/Claude/`** — Claude API integration:
- `ClaudeAPIClient` — streams SSE text deltas from `https://api.anthropic.com/v1/messages`
- `PromptBuilder` — assembles (systemPrompt, userMessage). The system prompt uses an evidence-based longevity physician framing (Attia/Johnson/Longo frameworks). The user message contains the full metric snapshot, recovery breakdown, and profile.
- `KeychainManager` — API key stored in iOS Keychain (never in UserDefaults or code)

**`Vitalia/Models/`**:
- `MetricDefinition` — static definitions for all 30+ metrics: ID, display name, unit, category, evidence tier, optimal range bounds, longevity context. `MetricDefinition.all` is the canonical list iterated throughout the app.
- SwiftData models: `UserProfile`, `MetricConfig`, `DailySnapshot`, `LongevityPlan`

### Snapshot key conventions

The `[String: Double]` snapshot uses these naming patterns:
- `"rhr"`, `"hrv"` — **30-day averages** (primary values shown on dashboard and used in longevity score)
- `"rhr_today"`, `"hrv_today"` — overnight readings (used by `RecoveryScoreCalculator` and the detail view "Tonight vs 30-Day Average" section)
- `"hrv_baseline"` — 30-day average HRV (used by `RecoveryScoreCalculator` as baseline denominator)
- `"hrv_longterm_baseline"` — all-time HRV average (used by `LongevityScoreCalculator` for HRV trend scoring)
- `"rhr_baseline"`, `"rr_baseline"` — 30-day averages used as recovery baselines

### Heart rate zone definitions

`HealthKitWorkoutAnalyser` and `HealthKitHistoryFetcher` both use Apple Health's 5-zone model. Zones 2–5 divide the 70–100% max HR range into four equal 7.5% bands:

| Zone | % max HR | Maps to |
|------|----------|---------|
| 1 | < 70% | — (not counted) |
| 2 | 70–77.5% | `zone2_minutes` |
| 3 | 77.5–85% | `vigorous_minutes` |
| 4 | 85–92.5% | `vigorous_minutes` |
| 5 | > 92.5% | `vigorous_minutes` |

Max HR is calculated as `220 - userAge`. **Both files must be kept in sync** — any threshold change needs updating in `HealthKitWorkoutAnalyser.swift` and `HealthKitHistoryFetcher.swift`.

### Design constraints

- **Zero external dependencies** — no SPM packages, no CocoaPods. Use only Apple frameworks.
- **Swift 6 strict concurrency** (`SWIFT_STRICT_CONCURRENCY: complete`). All HealthKit callbacks are bridged via `withCheckedContinuation`. UI state mutations must be on `@MainActor`.
- **On-device only** — health data never leaves the device except for anonymised metric summaries sent to Claude. No analytics, no crash reporting, no backend.
- **Dark mode only** — enforced at the app level.

## Spec

`docs/SPEC.md` is the authoritative product specification. Read it for intent behind any metric, scoring formula, or UX decision before making changes.

## Feature & Issue Tracking

**New features** are tracked in `docs/NewFeatures.md` as a markdown checklist.
- When the user describes a new feature to implement, add it as `- [ ] <description>` before starting work.
- Tick it off (`- [x]`) immediately after it is implemented and committed.

**Bugs and issues** are tracked in `docs/Issues.md` as a markdown checklist.
- When a bug or issue is identified (by the user or discovered during work), add it as `- [ ] <description>` before starting work.
- Tick it off (`- [x]`) immediately after it is fixed and committed.

Always commit updates to these docs in the same commit as the implementation.

# Vitalia Scoring Documentation

This document explains exactly how the Recovery Score, Longevity Score, and each individual metric are calculated, and the evidence base for each target range.

---

## 1. Individual Metric Scoring

### 1.1 General Scoring Framework

Every metric is converted to a score from 0–100 using a **non-linear piecewise decay** function based on how far the value deviates from its optimal range. The function penalises deviation progressively more harshly the further from optimal you are.

**Deviation** is defined as the proportional distance outside the optimal range:
- If value < optimalLow: `deviation = (optimalLow − value) / optimalLow`
- If value > optimalHigh: `deviation = (value − optimalHigh) / optimalHigh`
- If within range: `deviation = 0` → score = 100

**Scoring decay curve:**

| Deviation | Score range | Drop per 1% deviation |
|---|---|---|
| 0–10% | 100 → 80 | 2 pts |
| 10–30% | 80 → 50 | 1.5 pts |
| 30–60% | 50 → 20 | 1 pt |
| 60%+ | 20 → 0 | 0.5 pts |

The curve is intentionally steep near the edges of optimal (motivating small improvements) but flattens at extreme deviations (avoiding demotivating scores of 0 for difficult-to-change metrics).

**Status thresholds:**
- **Optimal**: score ≥ 85
- **Borderline**: score 55–84
- **Out of Range**: score < 55

**One-sided bounds:**
- If only a lower bound exists (e.g., VO₂ Max ≥ 55): values at or above the bound score 100. Values below decay normally.
- If only an upper bound exists (e.g., walking HR ≤ 70): values at or below the bound score 100. Values above decay normally.
- No bounds (HRV): scored relative to personal 30-day baseline via the Recovery Score algorithm; returns a neutral 75 in the Longevity Score since individual HRV is not comparable across people.

**Data source:** All activity metrics are **30-day rolling daily averages**. Overnight metrics (HRV, RHR, SpO₂, respiratory rate, wrist temp) use the most recent overnight window (21:00–09:00). VO₂ Max uses the maximum reading from the last 30 days. Body metrics use the latest recorded value.

---

### 1.2 Per-Metric Reference

#### Cardiovascular

---

**VO₂ Max** | Tier 1 | `≥ 55 mL/kg/min` for optimal
- *What it measures:* Maximal oxygen uptake — the rate at which your body can use oxygen during peak exercise. Apple Watch uses exercise HR to estimate it.
- *Apple Watch correction:* Apple Watch is known to underestimate VO₂ Max by ~3.5 mL/kg/min vs lab measurement. The app adds +3.5 to the raw value before scoring.
- *Optimal:* ≥ 55 mL/kg/min (no upper penalty)
- *Evidence:* The highest-ranked single predictor of all-cause mortality. In the CRF Consortium study (Ross et al., JACC 2016, n=122,007), moving from the bottom to the top fitness quintile was associated with a 45% reduction in all-cause mortality. Individuals in the top 2.5% of cardiorespiratory fitness had ~5× lower risk vs the bottom quartile. A VO₂ Max of 55+ mL/kg/min corresponds to the top ~20th percentile for men in their 30s–40s.

---

**Resting Heart Rate** | Tier 1 | `45–50 bpm` optimal
- *What it measures:* Overnight minimum heart rate — the most stable measure of true resting cardiac output.
- *Optimal:* 45–50 bpm
- *Evidence:* The Copenhagen Heart Study (n=29,325, Aune et al.) found every 10 bpm increase in RHR above 45 bpm associated with ~16% increased cardiovascular mortality. Below 40 bpm in non-athletes can reflect conduction abnormalities. Highly trained endurance athletes typically sit 38–50 bpm; the 45–50 range is optimal for a moderately-to-well trained individual. Values above 55 bpm are increasingly penalised.

---

**Heart Rate Variability (HRV)** | Tier 1 | Baseline-relative
- *What it measures:* Standard deviation of time between consecutive heartbeats (SDNN) during overnight sleep. Reflects autonomic nervous system balance — higher is better.
- *Optimal:* Not scored on absolute value. HRV varies enormously across individuals (range 20–100+ ms). Scored **relative to your personal 30-day baseline** within the Recovery Score (see Section 2).
- *Longevity Score treatment:* HRV has no universal optimal range, so it contributes a neutral score of 75 to the Longevity Score. Its primary role is in the Recovery Score where it carries 35% weight.
- *Evidence:* Low HRV is independently associated with increased all-cause mortality (Tsuji et al., Circulation 1994). HRV declines with age, chronic stress, overtraining, illness, and poor sleep. Improving HRV through consistent aerobic training, sleep, and stress management is measurable on a timescale of weeks.

---

**Systolic Blood Pressure** | Tier 1 | `100–120 mmHg` optimal
- *What it measures:* Peak arterial pressure during a heartbeat. Requires a compatible blood pressure monitor synced to Apple Health.
- *Optimal:* 100–120 mmHg
- *Evidence:* The SPRINT trial and subsequent meta-analyses identify systolic BP as the most important modifiable cardiovascular risk factor. Values of 115–120 mmHg associate with ~50% lower stroke risk vs 135–145 mmHg. The INTERHEART study attributed 49% of population-attributable risk of MI to hypertension. Below 100 mmHg can indicate hypotension; above 130 mmHg is clinically stage 1 hypertension.

---

**Blood Oxygen (SpO₂)** | Tier 1 | `97–100%` optimal
- *What it measures:* Overnight minimum peripheral oxygen saturation — the lowest reading during sleep, reflecting worst-case oxygenation.
- *Optimal:* 97–100%
- *Evidence:* Chronic overnight hypoxemia (SpO₂ < 90%) is a diagnostic criterion for sleep apnoea, which independently increases all-cause mortality 1.5–3× (Young et al., Sleep 2008). The overnight minimum is the clinically meaningful value — transient dips below 90% signal obstructive apnoea events. Values 95–96% are borderline; 97%+ is optimal.

---

**Walking Heart Rate** | Tier 2 | `≤ 70 bpm` optimal
- *What it measures:* Average HR during casual low-intensity walking. Reflects cardiovascular efficiency at sub-maximal effort.
- *Optimal:* ≤ 70 bpm (no lower penalty)
- *Evidence:* A downward trend in walking HR reflects improving stroke volume and cardiac efficiency — a positive adaptation to aerobic training. No large mortality trial specifically studies walking HR, but it is a sensitive marker of fitness improvement on the same physiological axis as RHR.

---

**Cardio Recovery** | Tier 2 | `≥ 20 bpm/min` optimal
- *What it measures:* Heart rate drop in the first minute after peak exercise intensity.
- *Optimal:* ≥ 20 bpm/min (no upper penalty)
- *Evidence:* Cole et al. (NEJM 1999, n=5,234) found that HRR < 12 bpm at 1 minute post-exercise was an independent predictor of mortality (RR 2.0) after adjustment for standard risk factors. Values ≥ 20 bpm/min are considered good; elite athletes often exceed 30 bpm/min.

---

#### Sleep

---

**Sleep Duration** | Tier 1 | `7–8.5 hours` optimal
- *What it measures:* Total time asleep (not time in bed) from last night's primary sleep session.
- *Optimal:* 7–8.5 hours
- *Evidence:* U-shaped mortality curve. Irwin et al. (SLEEP 2016) meta-analysis (n=1.3M) found short sleep (< 6 hrs) and long sleep (> 9 hrs) both associated with ~30% increased all-cause mortality. The optimal window of 7–8.5 hrs is consistent across Cappuccio et al. (Sleep 2010), the Nurses' Health Study, and the NIH Women's Health Initiative. Below 7 hrs impairs cognitive performance, insulin sensitivity, and immune function even without subjective sleepiness.

---

**Sleep Efficiency** | Tier 1 | `90–100%` optimal
- *What it measures:* Percentage of time in bed actually asleep (`total_sleep_time / time_in_bed × 100`).
- *Optimal:* ≥ 90%
- *Evidence:* Low sleep efficiency is a defining feature of insomnia and is independently associated with hypertension, depression, and metabolic syndrome. Values below 85% indicate clinically significant sleep fragmentation. The 90% threshold is used in Cognitive Behavioural Therapy for Insomnia (CBT-I) as the target for sleep restriction therapy.

---

**Deep Sleep** | Tier 1 | `≥ 13% of night` optimal
- *What it measures:* Percentage of total sleep in slow-wave (N3) sleep.
- *Optimal:* ≥ 13% (no upper penalty — more is unconditionally better)
- *Evidence:* Deep sleep is the primary stage for cellular repair, human growth hormone secretion, and memory consolidation. Deep sleep declines significantly with age (~2% per decade after 30). Chronic deep sleep deprivation is implicated in Alzheimer's risk via impaired glymphatic amyloid clearance (Xie et al., Science 2013). The floor of 13% reflects the clinical threshold below which deep sleep is genuinely concerning; Apple Watch actigraphy typically reads 13–20% for healthy sleepers (slightly lower than lab polysomnography). Values in the 13–20% range score 100 — penalising this range would incorrectly flag normal, healthy sleep architecture.

---

**REM Sleep** | Tier 1 | `20–25% of night` optimal
- *What it measures:* Percentage of sleep in REM (rapid eye movement) stage.
- *Optimal:* 20–25%
- *Evidence:* REM sleep is essential for emotional regulation, procedural memory, and creativity. The Harvard Nurses' Health Study found low REM proportion associated with ~30% higher risk of all-cause mortality. Persistent REM suppression (common with alcohol consumption and many medications) is also linked to increased dementia risk (Pase et al., Nature Communications 2017).

---

**Awake During Night** | Tier 1 | `0–8% of night` optimal
- *What it measures:* Percentage of time in bed spent awake (awakenings and time to fall asleep).
- *Optimal:* ≤ 5% (lower is better)
- *Evidence:* Frequent awakenings disrupt sleep architecture continuity and are associated with elevated cortisol, increased sympathetic tone, and inflammatory markers. Values below 5% indicate essentially consolidated sleep. Above 10% is a clinical threshold for sleep fragmentation. This metric captures what sleep efficiency misses when time-in-bed is very long.

---

**5-Day Sleep Debt** | Tier 1 | `0–30 minutes` optimal
- *What it measures:* Cumulative sleep deficit vs a 7.5-hour-per-night target over the last 5 nights. Negative debt means you've banked extra sleep.
- *Optimal:* 0–30 minutes accumulated deficit
- *Evidence:* Van Dongen et al. (Sleep 2003) demonstrated that 6 hrs/night for 14 days produces cognitive deficits equivalent to 24 hours of total sleep deprivation. Critically, subjects did not report feeling impaired — chronic restriction creates adapted sleepiness. The 7.5-hour target is set slightly above the minimum (7 hrs) to account for sleep efficiency losses. 30 minutes of debt is a conservative buffer.

---

**Sleep Consistency** | Tier 2 | `≤ 20 minutes variance` optimal
- *What it measures:* Standard deviation of bedtime across the last 7 nights.
- *Optimal:* ≤ 20 minutes standard deviation
- *Evidence:* Irregular sleep timing independently disrupts circadian rhythms even when total sleep duration is adequate. Phillips et al. (Science Advances 2017) found that irregular sleep schedules were associated with lower GPA, but subsequent metabolic studies (Baron et al., Sleep 2017) linked circadian misalignment with insulin resistance, obesity, and cardiovascular risk — independent of sleep duration.

---

**Respiratory Rate** | Tier 2 | `12–15 breaths/min` overnight
- *What it measures:* Average breathing rate during sleep. Measured by Apple Watch via respiratory effort sensing.
- *Optimal:* 12–15 breaths/min
- *Evidence:* Stable overnight respiratory rate is a marker of healthy cardiorespiratory regulation. Elevation above baseline is one of the earliest signs of illness (viral infection, overtraining syndrome, sleep apnoea exacerbation). In the Recovery Score, RR is compared to the individual's 30-day personal baseline rather than a fixed range, because absolute RR varies across individuals by up to 4 breaths/min.

---

#### Activity

---

**Daily Steps** | Tier 1 | `≥ 10,000 steps/day` (30-day average)
- *What it measures:* Average daily step count over the last 30 days. More steps is unconditionally better — no upper penalty.
- *Optimal:* ≥ 10,000 steps (no upper bound)
- *Evidence:* Paluch et al. (Lancet 2022, meta-analysis n=47,471) found each 1,000-step increment from 4,000 to 10,000 steps/day associated with progressive mortality reduction (~15% per 1,000 steps). At 10,000 steps, the curve substantially flattens but does not reverse — more steps does not harm longevity. The WHO 10,000-step recommendation aligns with this dose-response data.

---

**Zone 2 / Week** | Tier 1 | `≥ 180 min/week` (30-day average)
- *What it measures:* Minutes per week at 60–70% of maximum HR (max HR = 220 − age). Averaged over 30 days.
- *Optimal:* ≥ 180 min/week (no upper penalty)
- *Evidence:* Zone 2 training is the primary stimulus for mitochondrial biogenesis (PGC-1α upregulation) and the primary driver of VO₂ Max improvement in less-fit individuals. Iñigo San Millán's work (reviewed in Cell Metabolism 2021) identifies 3+ hours/week as the minimum effective dose. Peter Attia's framework targets 4–6 hours/week for longevity optimisation. Zone 2 specifically improves metabolic flexibility (fat oxidation), lowers resting RHR, and reduces all-cause mortality through multiple mechanisms beyond steps.

---

**Vigorous / Week** | Tier 1 | `20–30 min/week` (30-day average)
- *What it measures:* Minutes per week above 80% max HR. Averaged over 30 days.
- *Optimal:* 20–30 min/week
- *Evidence:* High-intensity intervals provide VO₂ Max ceiling extension and insulin sensitisation beyond what Zone 2 alone achieves (Helgerud et al., Medicine & Science in Sports & Exercise 2007). The WHO physical activity guidelines identify 75 min/week of vigorous activity as the minimum. However, beyond ~30 min/week for non-athletes, marginal returns diminish and recovery cost increases, hence the upper bound. This is not a hard penalty — borderline status applies 30–60 min/week, not a cliff.

---

**Strength Sessions / Week** | Tier 1 | `≥ 3 sessions/week` (30-day average)
- *What it measures:* Resistance training sessions per week, averaged over 30 days. Counts: traditional strength training, functional strength, HIIT, core training, cross-training, gymnastics, wrestling.
- *Optimal:* ≥ 3 sessions/week (no upper penalty)
- *Evidence:* Muscle mass and grip strength are independently predictive of all-cause mortality. Liu et al. (BMJ 2019) meta-analysis (n=1.5M) found 2–3 resistance sessions/week associated with 21–23% lower all-cause mortality. Sarcopenia (muscle loss with ageing) is a primary pathway for loss of functional independence. The 3 session/week threshold is consistent across the literature for maintaining or building mass.

---

**Training Load** | Tier 2 | No fixed optimal (contextual)
- *What it measures:* Weekly arbitrary training load units = Σ(avgHRpercentage × workout_duration_mins) across all workouts, averaged over 30 days.
- *Optimal:* No universal range — value is in tracking trends and contextualising the Recovery Score. A sustained high load with low recovery scores indicates overtraining; a very low load with high recovery suggests detraining.
- *Evidence:* Training load quantification frameworks (Foster's session RPE method; Banister's TRIMP) are validated proxies for cumulative physiological stress. No mortality range exists — this metric is informational for Claude's plan generation.

---

**Stand Hours / Day** | Tier 2 | `≥ 12 hrs/day` (30-day average)
- *What it measures:* Average number of hours per day in which you stood for at least 1 minute, sourced from `HKCategoryType(.appleStandHour)` — the same data that drives the Apple Watch Stand ring. 12 stand hours/day = ring completion. 30-day daily average.
- *Optimal:* ≥ 12 hours (no upper penalty — scoring 100 at exactly 12)
- *Evidence:* Sedentary behaviour is an independent mortality risk factor even in those meeting exercise guidelines (Biswas et al., Ann Intern Med 2015). Breaking up sitting time every 30–60 minutes improves postprandial glucose, endothelial function, and NEAT (non-exercise activity thermogenesis). 12 active hours out of a ~16-hour waking day is achievable and reflects the target of no more than 4 consecutive inactive hours.

---

#### Body Composition

---

**BMI** | Tier 2 | `20–24 kg/m²` optimal
- *What it measures:* Calculated from your latest HealthKit height and weight as `weight_kg / height_m²`. Updates when you sync.
- *Optimal:* 20–24 kg/m²
- *Caveat:* BMI is a crude proxy that cannot distinguish fat mass from lean mass. A muscular individual may have BMI > 25 with very low body fat. For this reason BMI is Tier 2 and will be superseded by body fat % when available from a compatible scale.
- *Evidence:* The Global BMI Mortality Collaboration (Lancet 2016, n=10.6M) found lowest all-cause mortality at BMI 20–25. Below 18.5 (underweight) and above 30 (obesity) carry progressively elevated risk. The 20–24 optimal window reflects the lowest-risk portion of this curve. Above 27.5 is associated with meaningful cardiovascular risk even in otherwise healthy individuals.

---

**Weight Trend** | Tier 2 | No scored range (informational)
- *What it measures:* Latest body weight in kg from HealthKit. Scored without a fixed optimal since a healthy weight is highly individual (depends on height, muscle mass, and sex).
- *Scoring:* Contributes a neutral score to the Longevity Score. Its primary value is showing Claude your absolute weight for plan personalisation, and flagging large changes over time. Use BMI for scored evaluation of body composition status.
- *Evidence:* Unintentional weight loss > 5% of body weight over 6–12 months is a clinical red flag for underlying illness. Weight stability within a healthy range is a more actionable longevity target than any single absolute weight.

---

#### Stress & Recovery

---

**Mindful Minutes / Day** | Tier 2 | `≥ 10 min/day` (30-day average)
- *What it measures:* Average daily minutes of Apple Health mindfulness sessions over 30 days. Only populated if you use the Mindfulness app or a compatible app.
- *Optimal:* ≥ 10 min/day (no upper penalty)
- *Evidence:* Goyal et al. (JAMA Internal Medicine 2014, meta-analysis) found mindfulness meditation programmes significantly reduced anxiety, depression, and pain with moderate effect sizes. HRV improvements and cortisol reductions have been observed with as little as 8 minutes/day (Tang et al., PNAS 2007). The 10-minute threshold aligns with validated minimum effective dose protocols.
- *Note:* This metric scores 0 if you don't log mindfulness sessions. If you don't use the Mindfulness app, consider disabling this metric in Settings to prevent it dragging your Longevity Score.

---

**Daylight Exposure** | Tier 2 | `≥ 30 min/day` (30-day average)
- *What it measures:* Average daily minutes of outdoor light exposure over 30 days, measured by the ambient light sensor on Apple Watch/iPhone. Requires iOS 17.2+.
- *Optimal:* ≥ 30 min/day (no upper penalty)
- *Evidence:* Morning light exposure is the primary zeitgeber (time cue) for the circadian clock, suppressing residual melatonin and anchoring the sleep-wake cycle. Blume et al. (Neuropsychiatric Disease and Treatment 2019) reviews the evidence linking low daylight exposure to seasonal affective disorder, metabolic disruption, and poor sleep quality. Huberman Lab protocols advocate 10–30 minutes of outdoor morning light as the highest-leverage circadian intervention.

---

**Wrist Temperature Deviation** | Tier 3 | `−0.3 to +0.3°C` optimal
- *What it measures:* Difference between last night's overnight wrist temperature and your personal 30-day baseline. Requires Apple Watch Series 8 or Ultra.
- *Optimal:* ≤ 0.3°C deviation in either direction
- *Evidence:* Elevated wrist temperature during sleep (> +0.5°C above baseline) is associated with active immune response (illness, vaccination), elevated inflammatory state, or hormonal changes (ovulation phase in women). It is a sensitive early warning signal — wrist temp often elevates 1–2 days before subjective illness symptoms. The +0.3°C threshold is derived from Apple's own overnight temperature sensing validation work. This metric does not directly predict longevity; it provides a daily physiological state signal.

---

## 2. Recovery Score

The Recovery Score (0–100) is a **daily readiness score** calculated from overnight biometric data relative to your **personal 30-day baselines**. It is philosophically similar to WHOOP Recovery but uses HealthKit data sources rather than proprietary sensors.

### 2.1 Inputs and Weights

| Component | Source | Default Weight | Notes |
|---|---|---|---|
| HRV | Overnight SDNN average (21:00–09:00) | 35% | Requires Apple Watch Series 4+ |
| Resting HR | Overnight minimum HR | 25% | |
| Sleep Quality | Composite of efficiency, deep %, awake % | 20% | |
| Sleep Debt | 5-day rolling debt vs 7.5-hr target | 10% | |
| Respiratory Rate | Overnight average | 5% | |
| SpO₂ | Overnight minimum | 3% | |
| Wrist Temperature | Deviation from 30-day baseline | 2% | Series 8+ only |

**Weight redistribution:** If any input is unavailable (e.g., no SpO₂ reading, no wrist temp sensor), its weight is distributed proportionally across the remaining available inputs. The final weights always sum to 100%.

**Incomplete state:** If all three critical inputs (HRV, RHR, Sleep Quality) are simultaneously unavailable, the score is marked incomplete and not displayed numerically.

### 2.2 Component Algorithms

**HRV Score**

Uses today's overnight HRV vs your 30-day personal average HRV (baseline):

```
ratio = today_HRV / baseline_HRV

ratio ≥ 1.20  →  100
1.00–1.20     →  80 + (ratio − 1.0) / 0.20 × 20
0.80–1.00     →  50 + (ratio − 0.80) / 0.20 × 30
0.60–0.80     →  20 + (ratio − 0.60) / 0.20 × 30
< 0.60        →  max(0, ratio / 0.60 × 20)
```

*Rationale:* HRV of 20% above baseline = exceptional recovery; at baseline = average; 20% below = meaningfully suppressed autonomic function.

---

**RHR Score**

Uses delta between today's overnight minimum RHR and your 30-day average RHR:

```
delta = today_RHR − baseline_RHR   (negative = lower than usual = better)

delta ≤ −3    →  100
−3 to 0       →  75 + (−delta / 3) × 25
0 to +5       →  75 − (delta / 5) × 40
> +5          →  max(0, 35 − (delta − 5) × 7)
```

*Rationale:* RHR 3+ bpm below your personal baseline signals strong cardiac recovery. At baseline = moderate (75). Elevated RHR signals stress, illness, or poor recovery.

*Important distinction:* The RHR **Recovery Score** component is relative to your baseline and independent of the absolute value. The **Longevity Score** uses absolute values against the 45–50 bpm optimal range. These are separate evaluations — you can have good daily recovery with a chronically elevated RHR.

---

**Sleep Quality Score**

Composite of three sub-components:

```
efficiency_score  = clamp((efficiency − 70) / (95 − 70) × 100, 0, 100)
deep_score        = clamp((deep_pct − 10) / (25 − 10) × 100, 0, 100)
awake_score       = clamp((10 − awake_pct) / (10 − 2) × 100, 0, 100)

sleep_quality = efficiency_score × 0.40 + deep_score × 0.40 + awake_score × 0.20
```

Deep sleep % and awake % fall back to modest defaults (15% and 8% respectively) if unavailable, preserving a partial sleep quality score from efficiency alone.

---

**Sleep Debt Score**

Based on 5-day cumulative deficit vs 7.5-hr/night target:

```
debt ≤ 0 min    →  100
0–30 min        →  100 − debt/30 × 25
30–90 min       →  75 − (debt − 30)/60 × 40
> 90 min        →  max(0, 35 − (debt − 90) × 0.35)
```

---

**Respiratory Rate Score**

Scored as deviation from personal 30-day RR baseline:

```
deviation = abs(tonight_RR − baseline_RR)

dev ≤ 0.5       →  100
0.5–2.0         →  100 − (dev − 0.5) / 1.5 × 50
> 2.0           →  max(0, 50 − (dev − 2.0) × 15)
```

---

**SpO₂ Score**

Absolute scale based on overnight minimum:

```
SpO₂ ≥ 97%   →  100
95–97%        →  100 − (97 − SpO₂) / 2 × 40
90–95%        →  60 − (95 − SpO₂) / 5 × 50
< 90%         →  max(0, 10 − (90 − SpO₂) × 2)
```

---

**Wrist Temperature Score**

Based on absolute deviation from 30-day baseline:

```
abs_dev ≤ 0.3°C   →  100
0.3–0.8°C         →  100 − (abs_dev − 0.3) / 0.5 × 50
> 0.8°C           →  max(0, 50 − (abs_dev − 0.8) × 50)
```

### 2.3 Recovery Bands

| Band | Score | Recommendation |
|---|---|---|
| Recovered | 85–100 | Push hard today — good conditions for high-intensity training |
| Moderate | 65–84 | Normal training is fine. Avoid max-effort sessions |
| Fatigued | 40–64 | Prioritise Zone 2 or active recovery. Investigate your sleep |
| Under-Recovered | 0–39 | Rest day recommended. Your body needs more time |

---

## 3. Longevity Score

The Longevity Score (0–100) is an **aggregate metric** reflecting how your overall health profile compares to evidence-based longevity optima across all tracked metrics. It weights metrics by the quality of their supporting evidence and applies a Tier 1 penalty to ensure critical metrics cannot be masked by average performance elsewhere.

### 3.1 Formula

```
Longevity Score = min(Tier1_scores) × 0.5 + evidence_weighted_average × 0.5
```

**Evidence-weighted average:**
```
weighted_avg = Σ(metric_score × tier_weight) / Σ(tier_weight)

Tier 1 weight = 3.0
Tier 2 weight = 2.0
Tier 3 weight = 1.0
```

**Tier 1 penalty:**
The minimum score among all Tier 1 metrics multiplies the formula by 0.5. This means a single severely out-of-range Tier 1 metric (e.g., VO₂ Max scoring 30) caps the total Longevity Score no higher than `30 × 0.5 + 100 × 0.5 = 65`, even if all other metrics are perfect.

*Rationale:* The strongest longevity evidence is concentrated in a small number of metrics (VO₂ Max, sleep duration, RHR, zone 2 exercise). High performance on Tier 3 metrics should not mask a critical Tier 1 failure.

### 3.2 Tier Assignments

**Tier 1 — Strongest mortality evidence (RCT/large cohort, direct causal link)**
- VO₂ Max
- Resting Heart Rate
- Heart Rate Variability
- Systolic Blood Pressure
- Blood Oxygen (SpO₂)
- Sleep Duration
- Sleep Efficiency
- Deep Sleep %
- REM Sleep %
- Awake % During Night
- 5-Day Sleep Debt
- Daily Steps
- Zone 2 Minutes / Week
- Vigorous Minutes / Week
- Strength Sessions / Week

**Tier 2 — Good supporting evidence (observational, mechanistic, or indirect)**
- Walking Heart Rate
- Cardio Recovery
- Sleep Consistency
- Respiratory Rate
- Training Load
- Active Hours / Day
- BMI
- Weight Trend
- Mindful Minutes
- Daylight Exposure

**Tier 3 — Emerging, indirect, or hardware-limited**
- Wrist Temperature Deviation

### 3.3 Metric Exclusions

Metrics are excluded from the Longevity Score if:
1. They have no optimal bounds (HRV — scored via Recovery Score instead; Training Load — no universal range)
2. They are explicitly disabled by the user in Settings
3. No data has been recorded (excluded silently — not penalised)

### 3.4 Score Interpretation

| Score | Interpretation |
|---|---|
| 85–100 | Excellent — top-tier longevity profile |
| 70–84 | Good — meaningful room for targeted improvement |
| 55–69 | Needs Work — several key metrics below optimal |
| < 55 | Critical — major gaps in longevity-critical metrics |

---

## 4. Focus Metric

After generating a Longevity Plan, Claude selects one **Focus Metric** — the single highest-leverage intervention given your current data. This is the metric where:

1. Evidence is strongest (Tier 1 preferred)
2. Current score is furthest below optimal
3. Improvement is actionable within 90 days

The focus metric is stored with each plan and displayed on the Dashboard as a persistent reminder of Claude's primary recommendation between plan generations.

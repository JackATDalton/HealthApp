import SwiftUI

struct RecoveryComponentDetailView: View {
    let componentKey:  String
    let componentName: String
    let score:         Double?
    let weight:        Double
    let snapshot:      [String: Double]

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.xl) {
                scoreHeader
                rawValuesSection
                scoringLogicSection
                weightSection
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.top, VSpacing.l)
            .padding(.bottom, VSpacing.huge)
        }
        .background(VColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(componentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Score header

    private var scoreHeader: some View {
        VStack(spacing: VSpacing.m) {
            if let s = score {
                ScoreRingView(
                    score: s,
                    color: scoreColor(s),
                    size: 140,
                    lineWidth: 14,
                    sublabel: scoreLabel(s)
                )
            } else {
                IncompleteRingView(size: 140, lineWidth: 14)
            }
            Text(info.subtitle)
                .font(VFont.captionFont)
                .foregroundStyle(VColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Raw values

    private var rawValuesSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Your Numbers")

            VStack(spacing: 0) {
                ForEach(Array(info.rawValues.enumerated()), id: \.element.label) { idx, row in
                    VStack(spacing: 0) {
                        HStack {
                            Text(row.label)
                                .font(VFont.bodyMediumFont)
                                .foregroundStyle(VColor.textSecondary)
                            Spacer()
                            Text(row.value)
                                .font(.system(size: VFont.bodyMedium, weight: .semibold, design: .monospaced))
                                .foregroundStyle(row.highlight ? scoreColor(score ?? 50) : VColor.textPrimary)
                        }
                        .padding(.horizontal, VSpacing.l)
                        .padding(.vertical, VSpacing.m)

                        if idx < info.rawValues.count - 1 {
                            Divider().background(VColor.borderSubtle).padding(.leading, VSpacing.l)
                        }
                    }
                }
            }
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Scoring logic

    private var scoringLogicSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "How This Is Scored")

            Text(info.scoringExplanation)
                .font(VFont.bodyMediumFont)
                .foregroundStyle(VColor.textSecondary)
                .lineSpacing(4)
                .padding(VSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))

            if let tip = info.improvementTip {
                HStack(alignment: .top, spacing: VSpacing.m) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(VColor.recoveryAmber)
                        .frame(width: 20)
                        .padding(.top, 2)
                    Text(tip)
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textSecondary)
                        .lineSpacing(4)
                }
                .padding(VSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VColor.recoveryAmber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            }
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Contribution to Recovery Score")

            HStack(spacing: VSpacing.m) {
                // Weight bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(VColor.borderSubtle).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VColor.accent)
                            .frame(width: geo.size.width * weight, height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(Int((weight * 100).rounded()))%")
                    .font(.system(size: VFont.bodyMedium, weight: .semibold))
                    .foregroundStyle(VColor.accent)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(VSpacing.l)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
    }

    // MARK: - Component info

    private struct ComponentInfo {
        let subtitle: String
        let rawValues: [(label: String, value: String, highlight: Bool)]
        let scoringExplanation: String
        let improvementTip: String?
    }

    private var info: ComponentInfo {
        switch componentKey {
        case "hrv":          return hrvInfo
        case "rhr":          return rhrInfo
        case "sleepQuality": return sleepQualityInfo
        case "sleepDebt":    return sleepDebtInfo
        case "rr":           return respiratoryRateInfo
        case "spo2":         return spo2Info
        case "wristTemp":    return wristTempInfo
        default:             return ComponentInfo(subtitle: "", rawValues: [], scoringExplanation: "", improvementTip: nil)
        }
    }

    private var hrvInfo: ComponentInfo {
        let hrv      = snapshot["hrv"].map      { String(format: "%.0f ms", $0) } ?? "—"
        let baseline = snapshot["hrv_baseline"].map { String(format: "%.0f ms", $0) } ?? "—"
        let ratioStr: String
        if let h = snapshot["hrv"], let b = snapshot["hrv_baseline"], b > 0 {
            ratioStr = String(format: "%.2f", h / b)
        } else { ratioStr = "—" }

        return ComponentInfo(
            subtitle: "Overnight HRV vs your 30-day personal baseline",
            rawValues: [
                (label: "Last night",     value: hrv,      highlight: true),
                (label: "30-day average", value: baseline, highlight: false),
                (label: "Ratio",          value: ratioStr, highlight: false),
            ],
            scoringExplanation: "Your overnight HRV is divided by your 30-day baseline to produce a ratio. A ratio ≥1.2 means you're well recovered (100). Between 1.0–1.2 scores 80–100. Between 0.8–1.0 scores 50–80 — mild suppression. Below 0.8 scores 20–50 and signals meaningful fatigue. Below 0.6 can score near zero.",
            improvementTip: "HRV rises with consistent sleep, reduced alcohol, lower training load, and aerobic base fitness. It is highly individual — trends matter more than absolute values."
        )
    }

    private var rhrInfo: ComponentInfo {
        let rhr      = snapshot["rhr"].map          { String(format: "%.0f bpm", $0) } ?? "—"
        let baseline = snapshot["rhr_baseline"].map { String(format: "%.0f bpm", $0) } ?? "—"
        let deltaStr: String
        if let r = snapshot["rhr"], let b = snapshot["rhr_baseline"] {
            let d = r - b
            deltaStr = d >= 0 ? String(format: "+%.0f bpm", d) : String(format: "%.0f bpm", d)
        } else { deltaStr = "—" }

        return ComponentInfo(
            subtitle: "Overnight minimum heart rate vs your 30-day baseline",
            rawValues: [
                (label: "Last night",        value: rhr,      highlight: true),
                (label: "30-day average",    value: baseline, highlight: false),
                (label: "vs baseline",       value: deltaStr, highlight: false),
            ],
            scoringExplanation: "Your overnight minimum RHR is compared to your personal 30-day average. ≥3 bpm below baseline → 100 (exceptional recovery). Within 0–5 bpm above → 75–35. Every bpm above baseline reflects increased sympathetic nervous system activity, which reduces recovery quality.",
            improvementTip: "Elevated RHR is often caused by poor sleep, alcohol, dehydration, illness, or high training load accumulated over several days. Identify the cause before training hard."
        )
    }

    private var sleepQualityInfo: ComponentInfo {
        let eff   = snapshot["sleep_efficiency"].map { String(format: "%.0f%%", $0) } ?? "—"
        let deep  = snapshot["deep_sleep_pct"].map   { String(format: "%.0f%%", $0) } ?? "—"
        let awake = snapshot["awake_pct"].map         { String(format: "%.0f%%", $0) } ?? "—"

        return ComponentInfo(
            subtitle: "Composite of sleep efficiency, deep sleep, and awake time",
            rawValues: [
                (label: "Sleep efficiency", value: eff,   highlight: true),
                (label: "Deep sleep",       value: deep,  highlight: false),
                (label: "Awake during night", value: awake, highlight: false),
            ],
            scoringExplanation: "Sleep Quality combines three metrics: efficiency (40% weight) — percentage of time in bed actually asleep; deep sleep % (40% weight) — target is ≥10%, optimal ≥20%; time awake (20% weight) — ≤2% is perfect, ≥10% significantly penalised. Each sub-score is 0–100 before being blended.",
            improvementTip: "Consistent bedtime, a cool dark room, and limiting alcohol all significantly improve deep sleep and efficiency. Fragmented sleep (high awake %) is often caused by caffeine, alcohol, or undiagnosed sleep apnoea."
        )
    }

    private var sleepDebtInfo: ComponentInfo {
        let debt = snapshot["sleep_debt"].map { String(format: "%.0f min", $0) } ?? "—"
        let nights = "5 nights (7.5 hr target)"

        return ComponentInfo(
            subtitle: "Cumulative sleep deficit over the last 5 nights",
            rawValues: [
                (label: "5-day debt",   value: debt,   highlight: true),
                (label: "Measured over", value: nights, highlight: false),
            ],
            scoringExplanation: "Cumulative sleep deficit is calculated by summing shortfalls vs a 7.5-hour nightly target over the past 5 nights. 0 min deficit → 100. Up to 30 min → 75–100. 30–90 min → 35–75. Beyond 90 min causes steep decline. Chronic sleep debt impairs cognitive function and recovery even when individual nights feel adequate.",
            improvementTip: "Prioritise an extra 30–60 minutes of sleep on nights following significant deficits. Naps of 20–30 min can partially offset acute debt without disrupting night sleep."
        )
    }

    private var respiratoryRateInfo: ComponentInfo {
        let rr       = snapshot["respiratory_rate"].map { String(format: "%.1f br/min", $0) } ?? "—"
        let baseline = snapshot["rr_baseline"].map      { String(format: "%.1f br/min", $0) } ?? "—"
        let devStr: String
        if let r = snapshot["respiratory_rate"], let b = snapshot["rr_baseline"] {
            let d = abs(r - b)
            devStr = String(format: "±%.1f from baseline", d)
        } else { devStr = "—" }

        return ComponentInfo(
            subtitle: "Overnight respiratory rate vs your 30-day baseline",
            rawValues: [
                (label: "Last night",     value: rr,      highlight: true),
                (label: "30-day average", value: baseline, highlight: false),
                (label: "Deviation",      value: devStr,  highlight: false),
            ],
            scoringExplanation: "Only elevation above your baseline is penalised — a lower rate than usual is a positive sign of deeper relaxation or improved cardiorespiratory efficiency. Within 0.5 br/min above baseline → 100. 0.5–2.0 br/min above → 50–100. Beyond 2.0 br/min above baseline drops steeply. Elevated respiratory rate overnight is an early indicator of illness or physiological stress before other symptoms appear.",
            improvementTip: "A consistently elevated respiratory rate (multiple nights) may be an early warning of illness or overtraining. Consider reducing training load and monitoring other recovery signals."
        )
    }

    private var spo2Info: ComponentInfo {
        let spo2 = snapshot["spo2"].map { String(format: "%.0f%%", $0) } ?? "—"

        return ComponentInfo(
            subtitle: "Overnight minimum blood oxygen saturation",
            rawValues: [
                (label: "Overnight minimum", value: spo2, highlight: true),
            ],
            scoringExplanation: "Overnight minimum SpO₂ is scored absolutely: ≥97% → 100 (ideal). 95–97% → 60–100 (acceptable range). 90–95% → 10–60 (clinically concerning — possible sleep-disordered breathing). Below 90% → near zero and warrants medical attention. Unlike other recovery metrics, SpO₂ is not compared to a baseline.",
            improvementTip: "Chronic dips below 94% overnight may indicate sleep apnoea. Side sleeping, weight loss, and nasal breathing can help, but persistent low SpO₂ warrants a clinical sleep study."
        )
    }

    private var wristTempInfo: ComponentInfo {
        let dev = snapshot["wrist_temp"].map { String(format: "%+.2f °C", $0) } ?? "—"

        return ComponentInfo(
            subtitle: "Wrist temperature deviation from your 30-day baseline during sleep",
            rawValues: [
                (label: "Deviation from baseline", value: dev, highlight: true),
            ],
            scoringExplanation: "Your overnight wrist temperature is compared to your 30-day sleeping baseline. Within ±0.3°C → 100 (normal variation). 0.3–0.8°C deviation → 50–100. Beyond 0.8°C → significant elevation. Wrist temperature rises before other symptoms during illness or immune activation, making it a useful early warning signal. It carries the lowest weight (2%) in the recovery score.",
            improvementTip: "An elevated wrist temperature on a single night is not necessarily significant. Two or more consecutive nights of elevation combined with other declining recovery signals warrants a rest day."
        )
    }

    // MARK: - Helpers

    private func scoreColor(_ s: Double) -> Color {
        if s >= 85 { return VColor.recoveryGreen }
        if s >= 65 { return VColor.recoveryAmber }
        if s >= 40 { return VColor.recoveryOrange }
        return VColor.recoveryRed
    }

    private func scoreLabel(_ s: Double) -> String {
        if s >= 85 { return "Excellent" }
        if s >= 65 { return "Good" }
        if s >= 40 { return "Fair" }
        return "Poor"
    }
}

import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \LongevityPlan.createdAt, order: .reverse) private var plans: [LongevityPlan]
    @Query private var profiles: [UserProfile]
    @Query private var metricConfigs: [MetricConfig]

    @AppStorage("preferredModel") private var preferredModel = "claude-sonnet-4-6"

    @State private var isGenerating = false
    @State private var streamingText = ""
    @State private var showHistory = false
    @State private var generationError: String? = nil
    @State private var showNoKeyAlert = false

    private var latestPlan: LongevityPlan? { plans.first }

    var body: some View {
        NavigationStack {
            ZStack {
                VColor.backgroundPrimary.ignoresSafeArea()

                if isGenerating {
                    streamingView
                } else if let plan = latestPlan {
                    planContentView(plan)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Longevity Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !plans.isEmpty && !isGenerating {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(VColor.textSecondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                PlanHistoryView(plans: plans)
            }
            .alert("API Key Required", isPresented: $showNoKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add your Anthropic API key in Settings → Claude API to generate plans.")
            }
            .alert("Generation Failed", isPresented: .init(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )) {
                Button("OK", role: .cancel) { generationError = nil }
            } message: {
                Text(generationError ?? "")
            }
        }
    }

    // MARK: - Streaming view

    private var streamingView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: VSpacing.l) {
                    HStack(spacing: VSpacing.s) {
                        PulsingDotView()
                        Text("Generating your plan…")
                            .font(VFont.bodySmallFont)
                            .foregroundStyle(VColor.textTertiary)
                    }
                    .padding(.horizontal, VSpacing.l)
                    .padding(.top, VSpacing.l)

                    StreamingPlanBodyView(text: streamingText)
                        .id("bottom")
                }
                .padding(.bottom, VSpacing.huge)
            }
            .onChange(of: streamingText) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - Plan content

    private func planContentView(_ plan: LongevityPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.xl) {
                // Plan header
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(plan.createdAt.formatted(date: .long, time: .omitted))
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Generated with \(plan.modelUsed)")
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.top, VSpacing.m)

                StreamingPlanBodyView(text: plan.fullText)

                generateButton
            }
            .padding(.bottom, VSpacing.huge)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: VSpacing.xxl) {
            Spacer()

            VStack(spacing: VSpacing.l) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(VColor.textTertiary)

                VStack(spacing: VSpacing.s) {
                    Text("No plan yet")
                        .font(VFont.titleSmallFont)
                        .foregroundStyle(VColor.textPrimary)
                    Text("Generate your first personalised longevity plan from your health data.")
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            generateButton
                .padding(.horizontal, VSpacing.l)
                .padding(.bottom, VSpacing.xl)
        }
    }

    // MARK: - Generate button

    private var generateButton: some View {
        Button {
            Task { await generatePlan() }
        } label: {
            HStack(spacing: VSpacing.s) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                Text(latestPlan == nil ? "Generate Plan" : "Regenerate Plan")
                    .font(.system(size: VFont.bodyLarge, weight: .semibold))
            }
            .foregroundStyle(VColor.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VSpacing.l)
            .background(isGenerating ? VColor.disabled : VColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
        .padding(.horizontal, VSpacing.l)
        .disabled(isGenerating)
    }

    // MARK: - Generation

    private func generatePlan() async {
        guard let apiKey = KeychainManager.loadAPIKey(), !apiKey.isEmpty else {
            showNoKeyAlert = true
            return
        }

        isGenerating = true
        streamingText = ""

        let (system, userMessage) = PromptBuilder.build(
            snapshot: appState.metricSnapshot,
            recoveryResult: appState.recoveryResult,
            longevityResult: appState.longevityResult,
            profile: profiles.first,
            configs: metricConfigs
        )

        do {
            let stream = ClaudeAPIClient.stream(
                apiKey: apiKey,
                model: preferredModel,
                system: system,
                userMessage: userMessage
            )

            for try await chunk in stream {
                streamingText += chunk
            }

            // Persist the completed plan
            let plan = LongevityPlan(modelUsed: preferredModel)
            plan.fullText = streamingText
            plan.focusMetricID = extractFocusMetricID(from: streamingText)
            if let encoded = try? JSONEncoder().encode(appState.metricSnapshot) {
                plan.snapshotData = encoded
            }
            context.insert(plan)
            try? context.save()

            appState.onPlanSaved(plan: plan)

        } catch {
            generationError = error.localizedDescription
        }

        isGenerating = false
    }

    /// Finds `metric_id: <id>` in the Focus Metric section and validates it.
    private func extractFocusMetricID(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var inFocusSection = false

        for line in lines {
            if line.hasPrefix("## Focus Metric") {
                inFocusSection = true
                continue
            }
            if inFocusSection && line.hasPrefix("##") {
                break // entered next section
            }
            if inFocusSection {
                let lower = line.lowercased()
                if lower.hasPrefix("metric_id:") {
                    let id = line
                        .dropFirst("metric_id:".count)
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                    if MetricDefinition.all.contains(where: { $0.id == id }) {
                        return id
                    }
                }
            }
        }

        // Fallback: match display names anywhere in the focus section text
        if let headerRange = text.range(of: "## Focus Metric") {
            let after = String(text[headerRange.upperBound...])
            for def in MetricDefinition.all {
                if after.localizedCaseInsensitiveContains(def.displayName) {
                    return def.id
                }
            }
        }
        return nil
    }
}

// MARK: - Streaming plan body

struct StreamingPlanBodyView: View {
    let text: String

    private var sections: [PlanSection] {
        PlanSection.parse(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.xl) {
            if sections.isEmpty {
                Text(text)
                    .font(VFont.bodyLargeFont)
                    .foregroundStyle(VColor.textSecondary)
                    .padding(.horizontal, VSpacing.l)
            } else {
                ForEach(sections) { section in
                    PlanSectionView(section: section)
                }
            }
        }
    }
}

// MARK: - Plan section model + parser

struct PlanSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    static func parse(from text: String) -> [PlanSection] {
        guard text.contains("##") else { return [] }
        var sections: [PlanSection] = []
        let lines = text.components(separatedBy: "\n")
        var currentTitle = ""
        var currentBody: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                if !currentTitle.isEmpty {
                    let body = currentBody
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // Strip "metric_id: ..." lines from user-visible body
                    let cleaned = body.components(separatedBy: "\n")
                        .filter { !$0.lowercased().hasPrefix("metric_id:") }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    sections.append(PlanSection(title: currentTitle, body: cleaned))
                }
                currentTitle = String(line.dropFirst(3))
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        if !currentTitle.isEmpty {
            let body = currentBody
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = body.components(separatedBy: "\n")
                .filter { !$0.lowercased().hasPrefix("metric_id:") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(PlanSection(title: currentTitle, body: cleaned))
        }
        return sections
    }
}

// MARK: - Plan section view

struct PlanSectionView: View {
    let section: PlanSection

    // Converts raw markdown body to a rendered Text view.
    // Pre-processes ### subheadings → **bold** so AttributedString handles them.
    @ViewBuilder private var renderedBody: some View {
        let processed = section.body
            .components(separatedBy: "\n")
            .map { line -> String in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("### ") { return "**\(t.dropFirst(4))**" }
                if t.hasPrefix("## ")  { return "**\(t.dropFirst(3))**" }
                return line
            }
            .joined(separator: "\n")
        if let attr = try? AttributedString(
            markdown: processed,
            options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
        ) {
            Text(attr)
        } else {
            Text(section.body)
        }
    }

    private var sectionIcon: String {
        switch section.title.lowercased() {
        case let t where t.contains("summary"):  "chart.bar.doc.horizontal"
        case let t where t.contains("priority"): "exclamationmark.triangle.fill"
        case let t where t.contains("action"):   "checklist"
        case let t where t.contains("quick"):    "star.fill"
        case let t where t.contains("focus"):    "scope"
        case let t where t.contains("workout"):  "figure.run"
        default:                                  "doc.text"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            // Section header with accent bar
            HStack(spacing: VSpacing.m) {
                RoundedRectangle(cornerRadius: VRadius.full)
                    .fill(VColor.accent)
                    .frame(width: 3, height: 22)

                Image(systemName: sectionIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VColor.accent)

                Text(section.title)
                    .font(VFont.titleSmallFont)
                    .foregroundStyle(VColor.textPrimary)
            }
            .padding(.horizontal, VSpacing.l)

            renderedBody
                .font(VFont.bodyLargeFont)
                .foregroundStyle(VColor.textSecondary)
                .lineSpacing(4)
                .padding(.horizontal, VSpacing.l)
        }
    }
}

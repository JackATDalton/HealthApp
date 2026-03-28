import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \LongevityPlan.createdAt, order: .reverse) private var plans: [LongevityPlan]
    @State private var isGenerating = false
    @State private var streamingText = ""
    @State private var showPromptPreview = false
    @State private var showHistory = false

    private var latestPlan: LongevityPlan? { plans.first }

    var body: some View {
        NavigationStack {
            ZStack {
                VColor.backgroundPrimary.ignoresSafeArea()

                if isGenerating {
                    streamingView
                } else if let plan = latestPlan {
                    planContentView(plan: plan)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Longevity Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !plans.isEmpty {
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

                    HStack {
                        Text("Generated with \(plan.modelUsed)")
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textTertiary)
                        Spacer()
                    }
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.top, VSpacing.m)

                StreamingPlanBodyView(text: plan.fullText)

                // Re-generate button
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
            // Phase 4: wire to ClaudeAPIClient
        } label: {
            HStack(spacing: VSpacing.s) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                Text("Generate Plan")
                    .font(.system(size: VFont.bodyLarge, weight: .semibold))
            }
            .foregroundStyle(VColor.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VSpacing.l)
            .background(VColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        }
        .padding(.horizontal, VSpacing.l)
        .disabled(isGenerating)
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
                    sections.append(PlanSection(title: currentTitle, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = String(line.dropFirst(3))
                currentBody = []
            } else {
                currentBody.append(line)
            }
        }
        if !currentTitle.isEmpty {
            sections.append(PlanSection(title: currentTitle, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return sections
    }
}

// MARK: - Plan section view

struct PlanSectionView: View {
    let section: PlanSection

    private var sectionIcon: String {
        switch section.title.lowercased() {
        case let t where t.contains("summary"):   "chart.bar.doc.horizontal"
        case let t where t.contains("priority"):  "exclamationmark.triangle.fill"
        case let t where t.contains("action"):    "checklist"
        case let t where t.contains("progress"):  "arrow.up.right.circle"
        case let t where t.contains("win"):       "star.fill"
        case let t where t.contains("focus"):     "scope"
        default:                                   "doc.text"
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

            // Body text
            Text(section.body)
                .font(VFont.bodyLargeFont)
                .foregroundStyle(VColor.textSecondary)
                .lineSpacing(4)
                .padding(.horizontal, VSpacing.l)
        }
    }
}

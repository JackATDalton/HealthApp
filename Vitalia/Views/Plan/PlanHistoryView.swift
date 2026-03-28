import SwiftUI

struct PlanHistoryView: View {
    let plans: [LongevityPlan]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: LongevityPlan?

    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    Button {
                        selectedPlan = plan
                    } label: {
                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                            Text(plan.createdAt.formatted(date: .complete, time: .omitted))
                                .font(VFont.bodyMediumFont)
                                .foregroundStyle(VColor.textPrimary)

                            if let summary = plan.statusSummary {
                                Text(summary)
                                    .font(VFont.bodySmallFont)
                                    .foregroundStyle(VColor.textSecondary)
                                    .lineLimit(2)
                            }

                            Text(plan.modelUsed)
                                .font(VFont.captionFont)
                                .foregroundStyle(VColor.textTertiary)
                        }
                        .padding(.vertical, VSpacing.xs)
                    }
                    .listRowBackground(VColor.backgroundSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VColor.backgroundPrimary)
            .navigationTitle("Plan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(VColor.accent)
                }
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailSheet(plan: plan)
            }
        }
        .presentationBackground(VColor.backgroundPrimary)
    }
}

private struct PlanDetailSheet: View {
    let plan: LongevityPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                StreamingPlanBodyView(text: plan.fullText)
                    .padding(.vertical, VSpacing.l)
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(plan.createdAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(VColor.accent)
                }
            }
        }
        .presentationBackground(VColor.backgroundPrimary)
    }
}

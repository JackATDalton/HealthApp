import SwiftUI
import SwiftData

struct OnboardingProfileView: View {
    @Binding var fitnessBackground: FitnessBackground
    @Binding var primaryGoal: PrimaryGoal
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: VSpacing.xs) {
                Text("About You")
                    .font(VFont.titleLargeFont)
                    .foregroundStyle(VColor.textPrimary)
                Text("Helps Vitalia calibrate your targets.")
                    .font(VFont.bodyMediumFont)
                    .foregroundStyle(VColor.textSecondary)
            }
            .padding(.top, VSpacing.huge)
            .padding(.horizontal, VSpacing.xl)

            Spacer()

            VStack(spacing: VSpacing.xxl) {
                // Fitness background
                VStack(alignment: .leading, spacing: VSpacing.m) {
                    sectionLabel("FITNESS BACKGROUND")
                    VStack(spacing: VSpacing.s) {
                        ForEach(FitnessBackground.allCases, id: \.self) { option in
                            selectionCard(
                                title: option.rawValue,
                                subtitle: fitnessSubtitle(option),
                                isSelected: fitnessBackground == option
                            ) { fitnessBackground = option }
                        }
                    }
                }

                // Primary goal
                VStack(alignment: .leading, spacing: VSpacing.m) {
                    sectionLabel("PRIMARY GOAL")
                    VStack(spacing: VSpacing.s) {
                        ForEach(PrimaryGoal.allCases, id: \.self) { option in
                            selectionCard(
                                title: option.rawValue,
                                subtitle: goalSubtitle(option),
                                isSelected: primaryGoal == option
                            ) { primaryGoal = option }
                        }
                    }
                }
            }
            .padding(.horizontal, VSpacing.l)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: VFont.bodyLarge, weight: .semibold))
                    .foregroundStyle(VColor.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VSpacing.l)
                    .background(VColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
            }
            .padding(.horizontal, VSpacing.l)
            .padding(.bottom, VSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColor.backgroundPrimary.ignoresSafeArea())
    }

    private func fitnessSubtitle(_ bg: FitnessBackground) -> String {
        switch bg {
        case .sedentary: "Little to no regular exercise"
        case .moderate:  "3–4 sessions per week"
        case .athlete:   "Training 5+ sessions per week"
        }
    }

    private func goalSubtitle(_ goal: PrimaryGoal) -> String {
        switch goal {
        case .longevity:   "Maximise lifespan and healthspan"
        case .performance: "More energy, better performance"
        case .prevention:  "Reduce risk of chronic disease"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(VFont.captionFont)
            .foregroundStyle(VColor.textTertiary)
            .tracking(0.8)
    }

    private func selectionCard(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: VSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: VFont.bodyMedium, weight: .semibold))
                        .foregroundStyle(isSelected ? VColor.textPrimary : VColor.textSecondary)
                    Text(subtitle)
                        .font(VFont.bodySmallFont)
                        .foregroundStyle(isSelected ? VColor.textSecondary : VColor.textTertiary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? VColor.accent : VColor.borderMedium, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(VColor.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(VSpacing.l)
            .background(isSelected ? VColor.accentFaint : VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.large)
                    .strokeBorder(isSelected ? VColor.accent.opacity(0.4) : VColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

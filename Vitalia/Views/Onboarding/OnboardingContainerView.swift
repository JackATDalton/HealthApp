import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var page: Int = 0
    @State private var fitnessBackground: FitnessBackground = .moderate
    @State private var primaryGoal: PrimaryGoal = .longevity
    @State private var disabledMetricIDs: Set<String> = []

    var body: some View {
        Group {
            switch page {
            case 0:
                OnboardingWelcomeView {
                    withAnimation(.easeInOut) { page = 1 }
                }
            case 1:
                OnboardingProfileView(
                    fitnessBackground: $fitnessBackground,
                    primaryGoal: $primaryGoal
                ) {
                    withAnimation(.easeInOut) { page = 2 }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .leading)
                ))
            case 2:
                OnboardingMetricsView(disabledMetricIDs: $disabledMetricIDs) {
                    Task { await completeOnboarding() }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .leading)
                ))
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    // MARK: - Complete

    private func completeOnboarding() async {
        // Create or update UserProfile
        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            context.insert(profile)
        }

        profile.fitnessBackground   = fitnessBackground
        profile.primaryGoal         = primaryGoal
        profile.onboardingComplete  = true
        profile.updatedAt           = Date()

        // Import HealthKit characteristics
        let store = HealthKitPermissionsManager().store
        let importer = HealthKitProfileImporter(store: store)
        let imported = await importer.importProfile()
        importer.applyTo(profile, imported: imported)

        // Persist default MetricConfigs (disabled ones)
        for id in disabledMetricIDs {
            let config = MetricConfig(metricID: id, isEnabled: false)
            context.insert(config)
        }

        try? context.save()

        // Start first sync
        appState.isOnboardingComplete = true
        await appState.sync()
    }
}

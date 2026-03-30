import SwiftUI
import SwiftData

@main
struct VitaliaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(SwiftDataContainer.shared)
    }
}

// MARK: - Root routing view

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if appState.isOnboardingComplete || (profiles.first?.onboardingComplete == true) {
                ContentView()
                    .task {
                        // Mark complete from persisted state on relaunch
                        if !appState.isOnboardingComplete {
                            appState.isOnboardingComplete = true
                        }
                        // Initial sync on every launch
                        await appState.sync(modelContext: context)
                    }
            } else {
                OnboardingContainerView()
            }
        }
        .onAppear {
            // Restore persisted onboarding state
            if profiles.first?.onboardingComplete == true {
                appState.isOnboardingComplete = true
            }
        }
    }
}

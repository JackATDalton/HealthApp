import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square.fill")
                }

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "text.document.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(VColor.accent)
        .onAppear {
            // Style the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(VColor.backgroundPrimary)

            // Unselected items
            let normal = UITabBarItemAppearance()
            normal.normal.iconColor = UIColor(VColor.textTertiary)
            normal.normal.titleTextAttributes = [.foregroundColor: UIColor(VColor.textTertiary)]
            normal.selected.iconColor = UIColor(VColor.accent)
            normal.selected.titleTextAttributes = [.foregroundColor: UIColor(VColor.accent)]
            appearance.stackedLayoutAppearance = normal

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

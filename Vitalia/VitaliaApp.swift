import SwiftUI
import SwiftData

@main
struct VitaliaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(SwiftDataContainer.shared)
    }
}

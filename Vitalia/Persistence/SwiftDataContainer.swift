import SwiftData

@MainActor
enum SwiftDataContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            MetricConfig.self,
            DailySnapshot.self,
            LongevityPlan.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    static var preview: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            MetricConfig.self,
            DailySnapshot.self,
            LongevityPlan.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
}

import SwiftUI
import Observation

@Observable
final class AppState {
    var isOnboardingComplete: Bool = false
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var showRePlanNudge: Bool = false

    // Current scores (populated after sync)
    var recoveryResult: RecoveryScoreResult? = nil
    var longevityScore: Double? = nil
    var focusMetricID: String? = nil

    // Mock state for Phase 1 — replace when HealthKit layer is wired
    func loadMockData() {
        recoveryResult = .mock
        longevityScore = 68
        focusMetricID = "vo2max"
        lastSyncDate = Date()
    }
}

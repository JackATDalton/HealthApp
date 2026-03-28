import SwiftData
import Foundation

enum FitnessBackground: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case moderate  = "Moderately Active"
    case athlete   = "Trained Athlete"
}

enum PrimaryGoal: String, Codable, CaseIterable {
    case longevity    = "Live as long as possible"
    case performance  = "Maximise energy & performance"
    case prevention   = "Disease prevention"
}

@Model
final class UserProfile {
    var dateOfBirth: Date?
    var biologicalSex: String = "unknown"
    var heightCm: Double?
    var weightKg: Double?
    var bloodType: String?
    var fitnessBackground: FitnessBackground = FitnessBackground.moderate
    var primaryGoal: PrimaryGoal = PrimaryGoal.longevity
    var preferMetric: Bool = true
    var onboardingComplete: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}

    var ageYears: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
}

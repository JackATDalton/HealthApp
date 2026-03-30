import HealthKit
import SwiftData

@MainActor
final class HealthKitProfileImporter {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    struct ImportedProfile {
        var dateOfBirth: Date?
        var biologicalSex: HKBiologicalSex?
        var bloodType: HKBloodType?
        var heightCm: Double?
        var weightKg: Double?
    }

    func importProfile() async -> ImportedProfile {
        var result = ImportedProfile()

        // Characteristics (synchronous, no query needed)
        result.dateOfBirth = (try? store.dateOfBirthComponents()).flatMap {
            Calendar.current.date(from: $0)
        }
        result.biologicalSex = (try? store.biologicalSex())?.biologicalSex
        result.bloodType = (try? store.bloodType())?.bloodType

        // Quantity samples
        async let height = fetchLatest(.init(.height), unit: .meterUnit(with: .centi))
        async let weight = fetchLatest(.init(.bodyMass), unit: .gramUnit(with: .kilo))
        result.heightCm = await height
        result.weightKg  = await weight

        return result
    }

    func applyTo(_ profile: UserProfile, imported: ImportedProfile) {
        if let dob = imported.dateOfBirth        { profile.dateOfBirth = dob }
        if let sex = imported.biologicalSex      { profile.biologicalSex = sex.stringValue }
        if let bt  = imported.bloodType          { profile.bloodType = bt.stringValue }
        if let h   = imported.heightCm           { profile.heightCm = h }
        if let w   = imported.weightKg           { profile.weightKg = w }
        profile.updatedAt = Date()
    }

    // MARK: - Private

    private func fetchLatest(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

// MARK: - HK enum → String helpers

private extension HKBiologicalSex {
    var stringValue: String {
        switch self {
        case .male:           "male"
        case .female:         "female"
        case .other:          "other"
        default:              "unknown"
        }
    }
}

private extension HKBloodType {
    var stringValue: String {
        switch self {
        case .aPositive:  "A+"
        case .aNegative:  "A−"
        case .bPositive:  "B+"
        case .bNegative:  "B−"
        case .abPositive: "AB+"
        case .abNegative: "AB−"
        case .oPositive:  "O+"
        case .oNegative:  "O−"
        default:          "Unknown"
        }
    }
}

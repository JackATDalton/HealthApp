import HealthKit

@MainActor
final class HealthKitPermissionsManager {
    let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // All types the app needs to read
    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            // Cardiovascular
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.appleWalkingHeartRateAverage),
            HKQuantityType(.vo2Max),
            HKQuantityType(.heartRateRecoveryOneMinute),
            // Blood pressure
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            // Activity
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleStandTime),
            // Body composition
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyMassIndex),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.height),
            // Mindfulness + environment
            HKQuantityType(.timeInDaylight),
            // Sleep + stress
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.mindfulSession),
            // Workout
            HKObjectType.workoutType(),
            // Characteristics
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex),
            HKCharacteristicType(.bloodType),
        ]
        // Wrist temperature: Series 8+ only
        if HKQuantityType.isIdentifierValid(
            HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue
        ) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        return types
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func isAuthorised(for type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }
}

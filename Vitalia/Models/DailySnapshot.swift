import SwiftData
import Foundation

@Model
final class DailySnapshot {
    var date: Date = Date()
    var metricValuesData: Data?
    var recoveryScore: Double?
    var recoveryBandRaw: String?
    var recoveryInputsData: Data?
    var recoveryIncompleteReasons: [String] = []
    var longevityScore: Double?
    var syncedAt: Date = Date()

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }

    var recoveryBand: RecoveryBand? {
        get { recoveryBandRaw.flatMap { RecoveryBand(rawValue: $0) } }
        set { recoveryBandRaw = newValue?.rawValue }
    }

    var metricValues: [String: Double] {
        get {
            guard let data = metricValuesData,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            metricValuesData = try? JSONEncoder().encode(newValue)
        }
    }
}

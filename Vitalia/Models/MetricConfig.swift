import SwiftData
import Foundation

@Model
final class MetricConfig {
    var metricID: String = ""
    var isEnabled: Bool = true
    var customRangeLow: Double?
    var customRangeHigh: Double?
    var updatedAt: Date = Date()

    init(metricID: String, isEnabled: Bool = true) {
        self.metricID = metricID
        self.isEnabled = isEnabled
    }
}

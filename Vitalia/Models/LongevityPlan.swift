import SwiftData
import Foundation

@Model
final class LongevityPlan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modelUsed: String = "claude-sonnet-4-6"
    var fullText: String = ""
    var snapshotData: Data?
    var focusMetricID: String?
    var statusSummary: String?

    init(modelUsed: String = "claude-sonnet-4-6") {
        self.modelUsed = modelUsed
    }
}

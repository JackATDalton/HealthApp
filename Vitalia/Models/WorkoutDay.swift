import Foundation

struct WorkoutDay: Identifiable {
    let id = UUID()
    let dayName: String
    let isRest: Bool
    let type: String?
    let duration: String?
    let zones: String?
    let notes: String?

    // MARK: - Parse from plan text

    static func parse(from planText: String) -> (context: String?, days: [WorkoutDay]) {
        guard let sectionRange = planText.range(of: "## Weekly Workout Plan") else {
            return (nil, [])
        }
        let afterHeader = String(planText[sectionRange.upperBound...])

        let sectionContent: String
        if let nextSection = afterHeader.range(of: "\n## ") {
            sectionContent = String(afterHeader[..<nextSection.lowerBound])
        } else {
            sectionContent = afterHeader
        }

        let lines = sectionContent.components(separatedBy: "\n")
        var days: [WorkoutDay] = []
        var planContext: String?
        var currentDay: String?
        var fields: [String: String] = [:]
        var isRest = false

        func flush() {
            guard let day = currentDay else { return }
            days.append(WorkoutDay(
                dayName: day,
                isRest: isRest,
                type: fields["type"],
                duration: fields["duration"],
                zones: fields["zones"],
                notes: fields["notes"]
            ))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                flush()
                currentDay = String(trimmed.dropFirst(4))
                fields = [:]
                isRest = false
            } else if trimmed.lowercased() == "rest" || trimmed.lowercased() == "rest day" {
                isRest = true
            } else if let colonIndex = trimmed.firstIndex(of: ":"), !trimmed.hasPrefix("#") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                switch key {
                case "context": planContext = value
                case "type", "duration", "zones", "notes": fields[key] = value
                default: break
                }
            }
        }
        flush()

        return (planContext, days)
    }
}

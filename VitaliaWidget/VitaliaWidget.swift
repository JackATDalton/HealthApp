import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct VitaliaWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let recoveryScore: Double?
    let recoveryBand: String
    let longevityScore: Double?
    let workoutIsRest: Bool
    let workoutType: String
    let workoutDuration: String
    let workoutZones: String
    let workoutNotes: String
    let workoutDayName: String

    static let placeholder = VitaliaWidgetEntry(
        date: Date(),
        recoveryScore: 72,
        recoveryBand: "Moderate",
        longevityScore: 68,
        workoutIsRest: false,
        workoutType: "Zone 2 Run",
        workoutDuration: "45 min",
        workoutZones: "Zone 2, 135–155 bpm",
        workoutNotes: "Keep conversational pace",
        workoutDayName: "Today"
    )

    static let empty = VitaliaWidgetEntry(
        date: Date(),
        recoveryScore: nil,
        recoveryBand: "—",
        longevityScore: nil,
        workoutIsRest: false,
        workoutType: "",
        workoutDuration: "",
        workoutZones: "",
        workoutNotes: "",
        workoutDayName: "Today"
    )
}

// MARK: - Timeline provider

struct VitaliaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitaliaWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (VitaliaWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<VitaliaWidgetEntry>) -> Void) {
        let entry = readEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func readEntry() -> VitaliaWidgetEntry {
        let d = UserDefaults(suiteName: "group.com.jackdalton.Vitalia")
        return VitaliaWidgetEntry(
            date: Date(),
            recoveryScore:  (d?.bool(forKey: "widget.recoveryValid") == true)  ? d?.double(forKey: "widget.recoveryScore")  : nil,
            recoveryBand:   d?.string(forKey: "widget.recoveryBand")   ?? "—",
            longevityScore: (d?.bool(forKey: "widget.longevityValid") == true) ? d?.double(forKey: "widget.longevityScore") : nil,
            workoutIsRest:  d?.bool(forKey: "widget.workoutIsRest")    ?? false,
            workoutType:    d?.string(forKey: "widget.workoutType")    ?? "",
            workoutDuration: d?.string(forKey: "widget.workoutDuration") ?? "",
            workoutZones:   d?.string(forKey: "widget.workoutZones")   ?? "",
            workoutNotes:   d?.string(forKey: "widget.workoutNotes")   ?? "",
            workoutDayName: d?.string(forKey: "widget.workoutDayName") ?? "Today"
        )
    }
}

// MARK: - Widget

struct VitaliaWidget: Widget {
    let kind = "VitaliaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitaliaTimelineProvider()) { entry in
            VitaliaWidgetView(entry: entry)
                .containerBackground(VColor.backgroundPrimary, for: .widget)
        }
        .configurationDisplayName("Vitalia")
        .description("Recovery, longevity, and today's workout.")
        .supportedFamilies([.systemLarge])
    }
}

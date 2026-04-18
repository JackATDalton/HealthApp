import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \LongevityPlan.createdAt, order: .reverse) private var plans: [LongevityPlan]

    private var latestPlan: LongevityPlan? { plans.first }

    private var parsedWorkoutPlan: (context: String?, days: [WorkoutDay]) {
        guard let plan = latestPlan else { return (nil, []) }
        return WorkoutDay.parse(from: plan.fullText)
    }

    private var todayWorkout: WorkoutDay? {
        let calendar = Calendar.current
        let weekday  = calendar.component(.weekday, from: Date())
        // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayName = dayNames[weekday - 1]
        return parsedWorkoutPlan.days.first {
            $0.dayName.lowercased().contains(todayName.lowercased()) ||
            todayName.lowercased().contains($0.dayName.lowercased().prefix(3))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.xl) {
                    // Today's suggested workout
                    todaySection

                    // This week's plan
                    if !parsedWorkoutPlan.days.isEmpty {
                        weeklyPlanSection
                    }

                    // Recent workout analysis
                    recentWorkoutsSection
                }
                .padding(.horizontal, VSpacing.l)
                .padding(.top, VSpacing.m)
                .padding(.bottom, 60)
            }
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Today section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Today")

            if let workout = todayWorkout {
                WorkoutDayCard(day: workout, isToday: true, recoveryScore: appState.recoveryResult?.score)
            } else if latestPlan == nil {
                noPlanCard
            } else {
                WorkoutDayCard(
                    day: WorkoutDay(dayName: "Today", isRest: true, type: nil, duration: nil, zones: nil, notes: nil),
                    isToday: true,
                    recoveryScore: appState.recoveryResult?.score
                )
            }
        }
    }

    // MARK: - Weekly plan section

    private var weeklyPlanSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "This Week's Plan")

            if let ctx = parsedWorkoutPlan.context {
                Text(ctx)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textTertiary)
                    .padding(.horizontal, VSpacing.xs)
            }

            ForEach(parsedWorkoutPlan.days) { day in
                WorkoutDayCard(day: day, isToday: false, recoveryScore: nil)
            }
        }
    }

    // MARK: - Recent workouts section

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.m) {
            SectionHeaderView(title: "Recent Workouts")

            if appState.recentWorkouts.isEmpty {
                emptyWorkoutsCard
            } else {
                ForEach(appState.recentWorkouts) { workout in
                    RecentWorkoutRow(workout: workout)
                }
            }
        }
    }

    // MARK: - Empty states

    private var noPlanCard: some View {
        HStack(spacing: VSpacing.m) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(VColor.textTertiary)

            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text("No plan generated yet")
                    .font(.system(size: VFont.bodyMedium, weight: .semibold))
                    .foregroundStyle(VColor.textPrimary)
                Text("Generate a longevity plan to get personalised daily workouts.")
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textSecondary)
            }
        }
        .padding(VSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
    }

    private var emptyWorkoutsCard: some View {
        Text("No recent workout data. Record workouts on your Apple Watch to see analysis here.")
            .font(VFont.bodySmallFont)
            .foregroundStyle(VColor.textTertiary)
            .padding(VSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
    }
}

// MARK: - WorkoutDayCard

struct WorkoutDayCard: View {
    let day: WorkoutDay
    let isToday: Bool
    let recoveryScore: Double?

    private var accentColor: Color {
        if day.isRest { return VColor.textTertiary }
        if let score = recoveryScore {
            if score >= 85 { return VColor.optimal }
            if score >= 65 { return VColor.borderline }
            return VColor.accent
        }
        return VColor.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.m) {
            // Day indicator
            VStack(spacing: 2) {
                Text(shortDayName)
                    .font(.system(size: VFont.bodySmall, weight: .bold))
                    .foregroundStyle(isToday ? accentColor : VColor.textTertiary)
                    .frame(width: 36)

                if isToday {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.top, 2)

            if day.isRest {
                restContent
            } else {
                workoutContent
            }
        }
        .padding(VSpacing.l)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.xl)
                .strokeBorder(isToday ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var shortDayName: String {
        String(day.dayName.prefix(3)).uppercased()
    }

    private var restContent: some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text("Rest Day")
                .font(.system(size: VFont.bodyMedium, weight: .semibold))
                .foregroundStyle(VColor.textSecondary)
            Text("Recovery & light movement")
                .font(VFont.bodySmallFont)
                .foregroundStyle(VColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workoutContent: some View {
        VStack(alignment: .leading, spacing: VSpacing.s) {
            HStack {
                Text(day.type ?? "Workout")
                    .font(.system(size: VFont.bodyMedium, weight: .semibold))
                    .foregroundStyle(VColor.textPrimary)

                Spacer()

                if let duration = day.duration {
                    Text(duration)
                        .font(.system(size: VFont.bodySmall, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, VSpacing.s)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let zones = day.zones {
                HStack(spacing: VSpacing.xs) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11))
                        .foregroundStyle(VColor.textTertiary)
                    Text(zones)
                        .font(VFont.bodySmallFont)
                        .foregroundStyle(VColor.textSecondary)
                }
            }

            if let notes = day.notes {
                Text(notes)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - RecentWorkoutRow

struct RecentWorkoutRow: View {
    let workout: HealthKitWorkoutAnalyser.RecentWorkout

    private var dateText: String {
        let cal = Calendar.current
        if cal.isDateInToday(workout.date)     { return "Today" }
        if cal.isDateInYesterday(workout.date) { return "Yesterday" }
        return workout.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var durationText: String {
        "\(Int(workout.durationMinutes.rounded())) min"
    }

    private var nonZoneMinutes: Double {
        max(0, workout.durationMinutes - workout.zone2Minutes - workout.vigorousMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.displayType)
                        .font(.system(size: VFont.bodyMedium, weight: .semibold))
                        .foregroundStyle(VColor.textPrimary)
                    Text(dateText)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                }

                Spacer()

                Text(durationText)
                    .font(.system(size: VFont.bodySmall, weight: .medium))
                    .foregroundStyle(VColor.textSecondary)
            }

            // Zone breakdown bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    let total = max(workout.durationMinutes, 1)
                    let greyW = geo.size.width * (nonZoneMinutes / total)
                    let z2W   = geo.size.width * (workout.zone2Minutes / total)
                    let vigW  = geo.size.width * (workout.vigorousMinutes / total)
                    HStack(spacing: 2) {
                        if nonZoneMinutes > 0 {
                            Capsule().fill(VColor.textTertiary.opacity(0.4))
                                .frame(width: max(greyW - 1, 0), height: 6)
                        }
                        if workout.zone2Minutes > 0 {
                            Capsule().fill(VColor.optimal)
                                .frame(width: max(z2W - 1, 0), height: 6)
                        }
                        if workout.vigorousMinutes > 0 {
                            Capsule().fill(VColor.excellent)
                                .frame(width: max(vigW - 1, 0), height: 6)
                        }
                    }
                }
                .frame(height: 6)

                HStack(spacing: VSpacing.m) {
                    if nonZoneMinutes > 0 {
                        Label("\(Int(nonZoneMinutes.rounded())) min Z1", systemImage: "circle.fill")
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.textTertiary)
                    }
                    if workout.zone2Minutes > 0 {
                        Label("\(Int(workout.zone2Minutes.rounded())) min Z2", systemImage: "circle.fill")
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.optimal)
                    }
                    if workout.vigorousMinutes > 0 {
                        Label("\(Int(workout.vigorousMinutes.rounded())) min Vig", systemImage: "circle.fill")
                            .font(VFont.captionFont)
                            .foregroundStyle(VColor.excellent)
                    }
                }
            }
        }
        .padding(VSpacing.l)
        .background(VColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
    }
}

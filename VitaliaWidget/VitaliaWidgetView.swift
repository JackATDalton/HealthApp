import WidgetKit
import SwiftUI

struct VitaliaWidgetView: View {
    let entry: VitaliaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("VITALIA")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WColor.textTertiary)
                .tracking(1.5)
                .padding(.bottom, WSpacing.m)

            HStack(spacing: WSpacing.l) {
                ScoreColumn(
                    title: "Recovery",
                    icon: "bolt.heart.fill",
                    score: entry.recoveryScore,
                    label: entry.recoveryBand
                )

                Rectangle()
                    .fill(WColor.textTertiary.opacity(0.15))
                    .frame(width: 1)

                ScoreColumn(
                    title: "Longevity",
                    icon: "figure.run.circle.fill",
                    score: entry.longevityScore,
                    label: entry.longevityScore.map { WColor.labelForScore($0) } ?? "—"
                )
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(WColor.textTertiary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, WSpacing.l)

            WorkoutSection(entry: entry)
        }
        .padding(WSpacing.l)
    }
}

// MARK: - Score column

private struct ScoreColumn: View {
    let title: String
    let icon: String
    let score: Double?
    let label: String

    private var color: Color {
        guard let score else { return WColor.textTertiary }
        return WColor.forScore(score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WColor.textSecondary)
                .labelStyle(.titleAndIcon)

            HStack(spacing: WSpacing.m) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.18), lineWidth: 6)
                    if let score {
                        Circle()
                            .trim(from: 0, to: min(score / 100, 1))
                            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    if let score {
                        Text("\(Int(score.rounded()))")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(WColor.textPrimary)
                            .contentTransition(.numericText())
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                    } else {
                        Text("—")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(WColor.textTertiary)
                        Text("No data")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(WColor.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Workout section

private struct WorkoutSection: View {
    let entry: VitaliaWidgetEntry

    private var accentColor: Color {
        guard let score = entry.recoveryScore else { return WColor.accent }
        return WColor.forScore(score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            Text("TODAY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WColor.textTertiary)
                .tracking(1.2)

            if entry.workoutType.isEmpty && !entry.workoutIsRest {
                Text("Generate a plan to see today's workout")
                    .font(.system(size: 13))
                    .foregroundStyle(WColor.textTertiary)
            } else if entry.workoutIsRest {
                HStack(spacing: WSpacing.s) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(WColor.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Day")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(WColor.textSecondary)
                        Text("Recovery & light movement")
                            .font(.system(size: 12))
                            .foregroundStyle(WColor.textTertiary)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: WSpacing.xs) {
                        Text(entry.workoutType)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(WColor.textPrimary)
                        if !entry.workoutZones.isEmpty {
                            Text(entry.workoutZones)
                                .font(.system(size: 12))
                                .foregroundStyle(WColor.textSecondary)
                        }
                        if !entry.workoutNotes.isEmpty {
                            Text(entry.workoutNotes)
                                .font(.system(size: 12))
                                .foregroundStyle(WColor.textTertiary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    if !entry.workoutDuration.isEmpty {
                        Text(entry.workoutDuration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, WSpacing.s)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

import WidgetKit
import SwiftUI

struct VitaliaWidgetView: View {
    let entry: VitaliaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("VITALIA")
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundStyle(VColor.textTertiary)
                .tracking(1.5)
                .padding(.bottom, VSpacing.m)

            // Scores row
            HStack(spacing: VSpacing.l) {
                ScoreColumn(
                    title: "Recovery",
                    icon: "bolt.heart.fill",
                    score: entry.recoveryScore,
                    label: entry.recoveryBand
                )

                Rectangle()
                    .fill(VColor.textTertiary.opacity(0.15))
                    .frame(width: 1)

                ScoreColumn(
                    title: "Longevity",
                    icon: "figure.run.circle.fill",
                    score: entry.longevityScore,
                    label: entry.longevityScore.map { VColor.labelForScore($0) } ?? "—"
                )
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(VColor.textTertiary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, VSpacing.l)

            // Today's workout
            WorkoutSection(entry: entry)
        }
        .padding(VSpacing.l)
    }
}

// MARK: - Score column

private struct ScoreColumn: View {
    let title: String
    let icon: String
    let score: Double?
    let label: String

    private var color: Color {
        guard let score else { return VColor.textTertiary }
        return VColor.forScore(score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.s) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VColor.textSecondary)
                .labelStyle(.titleAndIcon)

            HStack(spacing: VSpacing.m) {
                // Score ring
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
                            .foregroundStyle(VColor.textPrimary)
                            .contentTransition(.numericText())
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                    } else {
                        Text("—")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(VColor.textTertiary)
                        Text("No data")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(VColor.textTertiary)
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
        guard let score = entry.recoveryScore else { return VColor.accent }
        return VColor.forScore(score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.s) {
            HStack(spacing: VSpacing.xs) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VColor.textTertiary)
                    .tracking(1.2)
                Spacer()
            }

            if entry.workoutType.isEmpty && !entry.workoutIsRest {
                Text("Generate a plan to see today's workout")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(VColor.textTertiary)
            } else if entry.workoutIsRest {
                HStack(spacing: VSpacing.s) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(VColor.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Day")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VColor.textSecondary)
                        Text("Recovery & light movement")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(VColor.textTertiary)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(entry.workoutType)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VColor.textPrimary)

                        if !entry.workoutZones.isEmpty {
                            Text(entry.workoutZones)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(VColor.textSecondary)
                        }

                        if !entry.workoutNotes.isEmpty {
                            Text(entry.workoutNotes)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(VColor.textTertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if !entry.workoutDuration.isEmpty {
                        Text(entry.workoutDuration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, VSpacing.s)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

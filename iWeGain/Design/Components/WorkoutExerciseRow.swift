import SwiftUI

/// Exercise in the workout overview (Figma "Workout Exercise Row"): the exercise's own picture on a
/// tile coloured by [status], with a ✓ or skip mark in the corner once it's done or skipped. A `.partial`
/// exercise gets a pie of [doneShare] (done ÷ all its sets) instead, as not every set was done.
struct WorkoutExerciseRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: WorkoutExerciseStatus
    var doneShare: Double = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: icon, size: 56, iconSize: 32, foreground: iconColor, background: badgeColor)
                    .overlay(alignment: .bottomTrailing) { statusMark.offset(x: Spacing.x4, y: Spacing.x4) }
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title)
                        .textStyle(.headline)
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    Text(subtitle)
                        .textStyle(.footnote)
                        .foregroundStyle(status == .active ? Color.accentPrimary : Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("ic_chevron_right")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, 14)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .inset(by: 0.75)
                    .stroke(status == .active ? Color.accentPrimary : .clear, lineWidth: 1.5)
            )
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }

    private var badgeColor: Color {
        switch status {
        case .done, .partial: .accentSoft
        case .active: .accentPrimary
        case .upcoming, .skipped: .bgSurface2
        }
    }

    private var iconColor: Color {
        switch status {
        case .done, .partial: .accentPrimary
        case .active: .accentOn
        case .upcoming: .textSecondary
        case .skipped: .textTertiary
        }
    }

    private var titleColor: Color {
        switch status {
        case .done, .partial: .textSecondary
        case .skipped: .textTertiary
        case .active, .upcoming: .textPrimary
        }
    }

    @ViewBuilder
    private var statusMark: some View {
        switch status {
        case .done: StatusMark(icon: "ic_check", background: .accentPrimary, foreground: .accentOn)
        case .skipped: StatusMark(icon: "ic_skip_forward", background: .bgSurface2, foreground: .textSecondary)
        case .partial: DoneShareMark(share: doneShare)
        case .active, .upcoming: EmptyView()
        }
    }
}

/// Small round mark on the tile's corner, ringed in the card colour so it stands off the tile.
private struct StatusMark: View {
    let icon: String
    let background: Color
    let foreground: Color

    var body: some View {
        Image(icon)
            .resizable()
            .frame(width: 12, height: 12)
            .foregroundStyle(foreground)
            .frame(width: 18, height: 18)
            .background(background, in: .circle)
            .padding(2)
            .background(Color.bgSurface, in: .circle)
    }
}

/// The corner mark of a partly done exercise: a pie of [share], clockwise from 12 o'clock, on a grey disc.
private struct DoneShareMark: View {
    let share: Double

    var body: some View {
        ZStack {
            Circle().fill(Color.textTertiary)
            Circle()
                .trim(from: 0, to: min(max(share, 0), 1))
                .stroke(Color.accentPrimary, lineWidth: 8)
                .padding(4)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
        .padding(3)
        .background(Color.bgSurface, in: .circle)
    }
}

#Preview {
    VStack(spacing: Spacing.x12) {
        WorkoutExerciseRow(icon: "ic_ex_barbell_bench_press", title: "Bench Press", subtitle: "4 of 4 sets · best 100 kg × 5", status: .done, action: {})
        WorkoutExerciseRow(icon: "ic_ex_barbell_squat", title: "Squat", subtitle: "3 of 4 · 1 skipped · best 120 kg × 5", status: .partial, doneShare: 0.75, action: {})
        WorkoutExerciseRow(icon: "ic_ex_overhead_barbell_press", title: "Overhead Press", subtitle: "1 of 3 sets done · tap to continue", status: .active, action: {})
        WorkoutExerciseRow(icon: "ic_ex_triceps_pushdown", title: "Triceps Pushdown", subtitle: "3 sets · rest 60 s", status: .upcoming, action: {})
        WorkoutExerciseRow(icon: "ic_ex_dumbbell_lateral_raise", title: "Lateral Raise", subtitle: "Skipped · 1 of 3 sets done", status: .skipped, action: {})
    }
    .padding()
    .background(Color.bgBase)
}

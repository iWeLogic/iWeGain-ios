import SwiftUI

/// One logged set of [ExerciseResultCard]: "1 · 80 kg · × 10 ✓", or a muted skipped set.
struct ExerciseResultSet: Hashable {
    let number: Int
    let weight: String
    let reps: String
    let isDone: Bool
}

/// A finished exercise with its logged sets (Figma "Exercise Card"): the exercise's picture, name and
/// summary, then every set; [isRecord] shows the trophy "PR" badge.
struct ExerciseResultCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var isRecord = false
    let sets: [ExerciseResultSet]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x12) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: icon, size: 44, iconSize: 28)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                    Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isRecord {
                    HStack(spacing: Spacing.x4) {
                        Image("ic_trophy").resizable().frame(width: 14, height: 14)
                        Text("workout_details_pr").textStyle(.caption)
                    }
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.horizontal, Spacing.x8)
                    .padding(.vertical, Spacing.x4)
                    .background(Color.accentSoft, in: .capsule)
                }
            }
            Rectangle().fill(Color.borderDefault).frame(height: 1)
            ForEach(sets, id: \.self) { ResultSetRow(set: $0) }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

/// A finished exercise being edited (Figma "06b · Edit Workout"): every set opens [onSetTap] by its
/// index, "Add set" sits under the sets, and the trash icon in the header removes the exercise.
/// Without [onAddSet] and [onDelete] (a training's workout) the sets can only be changed.
struct ExerciseResultEditCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let sets: [ExerciseResultSet]
    let onSetTap: (Int) -> Void
    var onAddSet: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x12) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: icon, size: 44, iconSize: 28)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                    Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onDelete {
                    Button(action: onDelete) {
                        Image("ic_trash")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(Strings.format("workout_edit_delete_exercise_description", title)))
                }
            }
            Rectangle().fill(Color.borderDefault).frame(height: 1)
            VStack(spacing: 0) {
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    Button { onSetTap(index) } label: {
                        ResultSetRow(set: set, isEditable: true)
                            .frame(minHeight: 44)
                            .padding(.horizontal, Spacing.x4)
                            .contentShape(.rect(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityHint(Text("workout_edit_edit_set"))
                }
                if let onAddSet {
                    Button(action: onAddSet) {
                        HStack(spacing: Spacing.x8) {
                            Image("ic_plus").resizable().frame(width: 18, height: 18)
                            Text("workout_edit_add_set").textStyle(.subhead)
                        }
                        .foregroundStyle(Color.accentPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, Spacing.x4)
                        .contentShape(.rect(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct ResultSetRow: View {
    let set: ExerciseResultSet
    /// Edit workout: a skip icon for skipped sets and a chevron, since the row opens the set.
    var isEditable = false

    var body: some View {
        HStack(spacing: Spacing.x12) {
            Text("\(set.number)")
                .textStyle(.caption)
                .foregroundStyle(set.isDone ? Color.textSecondary : Color.textTertiary)
                .frame(width: 26, height: 26)
                .background(Color.bgSurface2, in: .circle)
            Text(set.weight)
                .textStyle(.callout)
                .foregroundStyle(set.isDone ? Color.textPrimary : Color.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(set.reps)
                .textStyle(.callout)
                .foregroundStyle(set.isDone ? Color.textSecondary : Color.textTertiary)
                .lineLimit(1)
            Image(set.isDone ? "ic_check" : "ic_skip_forward")
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(set.isDone ? Color.accentPrimary : Color.textTertiary)
                .opacity(set.isDone || isEditable ? 1 : 0)
            if isEditable {
                Image("ic_chevron_right").resizable().frame(width: 16, height: 16).foregroundStyle(Color.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ExerciseResultCard(
        icon: "ic_ex_barbell_bench_press", title: "Bench Press", subtitle: "4 sets · Best 100 kg × 5", isRecord: true,
        sets: [
            ExerciseResultSet(number: 1, weight: "80 kg", reps: "× 10", isDone: true),
            ExerciseResultSet(number: 2, weight: "90 kg", reps: "× 8", isDone: true),
            ExerciseResultSet(number: 3, weight: "100 kg", reps: "Skipped", isDone: false),
        ]
    )
    .padding()
    .background(Color.bgBase)
}

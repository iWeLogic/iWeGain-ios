import SwiftUI

/// Exercise library row: picture, name and "Muscle · Equipment". Tapping the row picks the exercise.
/// With [onEdit] (custom exercises) it also shows a pencil button.
struct ExerciseRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var onEdit: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.x12) {
            Button(action: action) {
                HStack(spacing: Spacing.x12) {
                    IconBadge.exercise(icon)
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text(title).textStyle(.body).foregroundStyle(Color.textPrimary).lineLimit(1)
                        Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            if let onEdit {
                Button(action: onEdit) {
                    Image("ic_pencil")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().inset(by: 0.75).stroke(Color.borderDefault, lineWidth: 1.5))
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Strings.format("exercise_edit", title))
            }
        }
        .padding(.horizontal, Spacing.x16)
        .padding(.vertical, Spacing.x12)
        .background(Color.bgSurface)
    }
}

/// Divider between [ExerciseRow]s, inset to start after the picture.
struct ExerciseRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderDefault)
            .frame(height: 1)
            .padding(.leading, Spacing.x16 + 56 + Spacing.x12)
            .background(Color.bgSurface)
    }
}

#Preview {
    VStack(spacing: 0) {
        ExerciseRow(icon: "ic_ex_barbell_bench_press", title: "Bench Press", subtitle: "Chest · Barbell", action: {})
        ExerciseRowDivider()
        ExerciseRow(icon: "ic_mountain", title: "Landmine Press", subtitle: "Shoulders · Barbell", action: {}, onEdit: {})
    }
    .clipShape(.rect(cornerRadius: Radius.lg))
    .padding()
    .background(Color.bgBase)
}

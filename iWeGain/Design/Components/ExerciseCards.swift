import SwiftUI

/// Read-only exercise inside a training: name, "Muscle · Equipment", sets and rest between sets.
struct ExerciseViewCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let sets: String
    let rest: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            ExerciseHeader(icon: icon, title: title, subtitle: subtitle)
            CardDivider()
            ValueRow(icon: "ic_check", label: Strings.text("exercise_sets")) { valueText(sets) }
            ValueRow(icon: "ic_clock", label: Strings.text("exercise_rest_between_sets")) { valueText(rest) }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }

    private func valueText(_ value: String) -> some View {
        Text(value).font(.custom(AppFont.semiBold, size: 15, relativeTo: .callout)).tracking(-0.2).foregroundStyle(Color.textPrimary)
    }
}

/// Exercise inside the training editor: drag handle, name, overflow menu, and steppers for the
/// number of sets and the rest between sets.
struct ExerciseEditCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let sets: String
    let rest: String
    let onSetsDecrease: () -> Void
    let onSetsIncrease: () -> Void
    let onRestDecrease: () -> Void
    let onRestIncrease: () -> Void
    let onRemove: () -> Void
    var canDecreaseSets = true
    var canIncreaseSets = true
    var canDecreaseRest = true
    var canIncreaseRest = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            HStack(spacing: Spacing.x12) {
                Image("ic_grip")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityLabel(Text("exercise_reorder"))
                ExerciseHeader(icon: icon, title: title, subtitle: subtitle)
                Menu {
                    Button("exercise_remove", image: ImageResource(name: "ic_trash", bundle: .main), role: .destructive, action: onRemove)
                } label: {
                    Image("ic_more")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Text("exercise_more_actions"))
                .padding(-12)
            }
            CardDivider()
            let setsLabel = Strings.text("exercise_sets")
            let restLabel = Strings.text("exercise_rest_between_sets")
            ValueRow(icon: "ic_check", label: setsLabel) {
                AppStepper(value: sets, label: setsLabel, onDecrease: onSetsDecrease, onIncrease: onSetsIncrease,
                           canDecrease: canDecreaseSets, canIncrease: canIncreaseSets)
            }
            ValueRow(icon: "ic_clock", label: restLabel) {
                AppStepper(value: rest, label: restLabel, onDecrease: onRestDecrease, onIncrease: onRestIncrease,
                           canDecrease: canDecreaseRest, canIncrease: canIncreaseRest)
            }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct ExerciseHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.x12) {
            IconBadge.exercise(icon)
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Color.borderDefault).frame(height: 1).padding(.vertical, Spacing.x4)
    }
}

private struct ValueRow<Value: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(spacing: Spacing.x8) {
            Image(icon).resizable().frame(width: 18, height: 18).foregroundStyle(Color.textSecondary)
            Text(label).textStyle(.callout).foregroundStyle(Color.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            value()
        }
    }
}

#Preview {
    VStack(spacing: Spacing.x12) {
        ExerciseViewCard(icon: "ic_ex_barbell_bench_press", title: "Bench Press", subtitle: "Chest · Barbell", sets: "4", rest: "90 s")
        ExerciseEditCard(icon: "ic_ex_barbell_bench_press", title: "Bench Press", subtitle: "Chest · Barbell", sets: "4", rest: "90 s",
                         onSetsDecrease: {}, onSetsIncrease: {}, onRestDecrease: {}, onRestIncrease: {}, onRemove: {})
    }
    .padding()
    .background(Color.bgBase)
}

import SwiftUI

/// "Finish workout?" confirmation with the sets that are still open (Figma "29 · Finish Workout").
/// A free workout also gets its name and "Save as training" (Figma "29c · Finish Free Workout").
struct FinishWorkoutSheet: View {
    let title: String
    let elapsed: String
    let summary: FinishSummaryUi
    let name: String
    let onAction: (WorkoutAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x20) {
                VStack(spacing: Spacing.x4) {
                    Text("finish_title")
                        .font(.custom(AppFont.bold, size: 20, relativeTo: .title3))
                        .foregroundStyle(Color.textPrimary)
                    Text(Strings.format("finish_subtitle", title, elapsed))
                        .textStyle(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if summary.isFree {
                    AppTextField(placeholder: "finish_name", text: name, onTextChange: { onAction(.onFinishNameChange($0)) }, background: .bgSurface2)
                }
                SummaryCard(summary: summary)
                if summary.isFree && summary.doneSets > 0 {
                    VStack(spacing: Spacing.x8) {
                        Toggle(isOn: Binding(get: { summary.saveAsTraining }, set: { onAction(.onSaveAsTrainingChange($0)) })) {
                            HStack(spacing: Spacing.x12) {
                                IconBadge(asset: "ic_dumbbell", size: 36, iconSize: 20, cornerRadius: Radius.sm)
                                Text("finish_save_as_training")
                                    .textStyle(.body)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .tint(Color.accentPrimary)
                        .padding(.horizontal, Spacing.x16)
                        .padding(.vertical, Spacing.x12)
                        .background(Color.bgSurface2, in: .rect(cornerRadius: 16))
                        Note("finish_save_as_training_hint")
                    }
                }
                if summary.isFree && summary.doneSets == 0 {
                    Note("finish_free_empty_note")
                } else if !summary.unfinished.isEmpty {
                    Note("finish_unfinished_note")
                }
                VStack(spacing: 10) {
                    Button { onAction(.onFinishConfirm) } label: { IconLabel("workout_finish", icon: "ic_trophy") }
                        .buttonStyle(.appPrimary)
                    Button("finish_keep_training") { onAction(.onFinishDismiss) }
                        .buttonStyle(.appSecondary)
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.top, Spacing.x24)
            .padding(.bottom, Spacing.x16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.bgSurface)
    }
}

private struct SummaryCard: View {
    let summary: FinishSummaryUi

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x12) {
            HStack {
                Text("finish_completed")
                    .textStyle(.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(Strings.format("finish_completed_value", summary.doneSets, summary.totalSets))
                    .textStyle(.subhead)
                    .foregroundStyle(Color.accentPrimary)
            }
            if !summary.unfinished.isEmpty {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                Text("finish_not_finished")
                    .textStyle(.caption)
                    .fontWeight(.semibold)
                    .tracking(0.48)
                    .foregroundStyle(Color.textTertiary)
                ForEach(summary.unfinished) { exercise in
                    HStack(spacing: Spacing.x12) {
                        Text(exercise.name)
                            .textStyle(.subhead)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(exercise.setsLeft)
                            .textStyle(.subhead)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface2, in: .rect(cornerRadius: 16))
    }
}

private struct Note: View {
    let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key)
            .textStyle(.footnote)
            .fontWeight(.medium)
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    Color.bgBase.sheet(isPresented: .constant(true)) {
        FinishWorkoutSheet(
            title: "Push Day",
            elapsed: "48:12",
            summary: FinishSummaryUi(doneSets: 8, totalSets: 10, unfinished: [UnfinishedExerciseUi(id: 2, name: "Triceps Pushdown", setsLeft: "2 sets left")]),
            name: "",
            onAction: { _ in }
        )
    }
}

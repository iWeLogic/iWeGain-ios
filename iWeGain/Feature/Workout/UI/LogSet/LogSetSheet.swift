import SwiftUI

/// "Set 2 done": weight and reps prefilled from the target, with an in-app keypad (Figma "14/15 · Log Set").
/// Editing a done set ("Edit set 1", Figma "14b") prefills what was logged and only saves.
struct LogSetSheet: View {
    let logSet: LogSetUi
    let onAction: (LogSetAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.x20) {
                    NumberInput(
                        label: logSet.weightLabel,
                        value: logSet.weight.isEmpty ? "0" : logSet.weight,
                        hint: logSet.weightHint,
                        isFocused: logSet.focused == .weight,
                        onValueTap: { onAction(.onFieldTap(.weight)) },
                        onDecrease: { onAction(.onWeightDecrease) },
                        onIncrease: { onAction(.onWeightIncrease) }
                    )
                    NumberInput(
                        label: Strings.text("log_set_reps"),
                        value: logSet.reps,
                        hint: logSet.repsHint,
                        isFocused: logSet.focused == .reps,
                        onValueTap: { onAction(.onFieldTap(.reps)) },
                        onDecrease: { onAction(.onRepsDecrease) },
                        onIncrease: { onAction(.onRepsIncrease) }
                    )
                    if let isDone = logSet.isDone {
                        VStack(spacing: Spacing.x8) {
                            Text("workout_edit_status").textStyle(.subhead).foregroundStyle(Color.textSecondary)
                            AppSegmentedControl(
                                options: ["workout_edit_status_done", "workout_details_set_skipped"],
                                selectedIndex: isDone ? 0 : 1,
                                onSelect: { onAction(.onStatusChange(isDone: $0 == 0)) },
                                trackColor: .bgBase
                            )
                        }
                    } else if logSet.focused == nil {
                        Text("log_set_type_hint")
                            .textStyle(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    Button { onAction(.onSave) } label: {
                        IconLabel(verbatim: logSet.saveTitle, icon: logSet.startsRest ? "ic_timer" : "ic_check")
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(!logSet.canSave)
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.vertical, Spacing.x16)
            }
            .scrollBounceBehavior(.basedOnSize)
            if let focused = logSet.focused {
                Keypad(
                    onKey: { onAction(.onKey($0)) },
                    onBackspace: { onAction(.onBackspace) },
                    showsDecimal: focused == .weight
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: logSet.focused)
        .background(Color.bgSurface)
        .navigationTitle(logSet.title)
        .navigationSubtitle(logSet.exerciseName)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { onAction(.onDismiss) }
            }
            if logSet.canDelete {
                ToolbarItem(placement: .destructiveAction) {
                    Button { onAction(.onDelete) } label: {
                        Image("ic_trash").resizable().frame(width: 20, height: 20)
                    }
                    .tint(Color.statusDanger)
                    .accessibilityLabel(Text("workout_edit_delete_set"))
                }
            }
        }
    }
}

#Preview {
    Color.bgBase.sheet(isPresented: .constant(true)) {
        NavigationStack {
            LogSetSheet(
                logSet: LogSetUi(setNumber: 2, exerciseName: "Bench Press", weightLabel: "Weight, kg", weight: "57.5", reps: "8",
                                 weightHint: "Last time: 55 kg", repsHint: "Last time: 8", focused: .weight, startsRest: true, canDelete: true),
                onAction: { _ in }
            )
        }
        .presentationDetents([.large])
    }
}

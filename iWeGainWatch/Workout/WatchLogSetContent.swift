import SwiftUI

/// Figma "55 · Watch · Log Set".
struct WatchLogSetContent: View {
    let logSet: WatchLogSet
    let canSave: Bool
    let onAction: (WatchWorkoutAction) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Stepper(
                label: "log_set_weight",
                value: logSet.weightText,
                unit: logSet.unit == .kg ? "unit_kg" : "unit_lb",
                canDecrease: logSet.canDecreaseWeight,
                onDecrease: { onAction(.onWeightChange(steps: -1)) },
                onIncrease: { onAction(.onWeightChange(steps: 1)) }
            )
            Stepper(
                label: "log_set_reps",
                value: "\(logSet.reps)",
                unit: nil,
                canDecrease: logSet.canDecreaseReps,
                onDecrease: { onAction(.onRepsChange(delta: -1)) },
                onIncrease: { onAction(.onRepsChange(delta: 1)) }
            )
            Spacer(minLength: 2)
            WatchPillButton(title: logSet.restFollows ? "log_set_save_rest" : "log_set_save", kind: canSave ? .primary : .disabled) {
                onAction(.onSaveTap)
            }
        }
        .padding(.horizontal, 6)
        .navigationTitle(Strings.format("log_set_title", logSet.setNumber))
    }
}

private struct Stepper: View {
    let label: LocalizedStringKey
    let value: String
    let unit: LocalizedStringKey?
    let canDecrease: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(label).watchText(12, .medium, color: .watchTextSecondary)
            HStack(spacing: 4) {
                WatchRoundButton(accessibilityText: Text("decrease") + Text(" ") + Text(label), isEnabled: canDecrease, action: onDecrease) {
                    WatchIcon(name: "ic_minus", size: 16, color: canDecrease ? .watchTextPrimary : .watchTextTertiary)
                }
                // "102.25 kg" or "225.5 lb" shrink a bit to fit between the buttons.
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).watchText(24, .bold)
                    if let unit { Text(unit).watchText(14, .medium, color: .watchTextSecondary) }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                WatchRoundButton(accessibilityText: Text("increase") + Text(" ") + Text(label), action: onIncrease) {
                    WatchIcon(name: "ic_plus", size: 16)
                }
            }
        }
    }
}

import SwiftUI

/// "− value +" pill. The value is pre-formatted by the caller (e.g. "4", "90 s").
struct AppStepper: View {
    let value: String
    /// What the stepper changes, for VoiceOver ("Decrease Sets").
    let label: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    var canDecrease = true
    var canIncrease = true

    var body: some View {
        HStack(spacing: Spacing.x4) {
            StepperButton(icon: "ic_minus", isEnabled: canDecrease, action: onDecrease)
                .accessibilityLabel(Strings.format("stepper_decrease", label))
            Text(value)
                .textStyle(.subhead)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 48)
            StepperButton(icon: "ic_plus", isEnabled: canIncrease, action: onIncrease)
                .accessibilityLabel(Strings.format("stepper_increase", label))
        }
        .padding(3)
        .background(Color.bgSurface2, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrease { onIncrease() }
            case .decrement: if canDecrease { onDecrease() }
            @unknown default: break
            }
        }
    }
}

private struct StepperButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(isEnabled ? Color.textPrimary : Color.textTertiary)
                .frame(width: 30, height: 30)
                .background(Color.bgSurface, in: .circle)
                // A bigger tap target than the drawn circle.
                .padding(4)
                .contentShape(.circle)
                .padding(-4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    AppStepper(value: "90 s", label: "Rest", onDecrease: {}, onIncrease: {})
        .padding()
        .background(Color.bgSurface)
}

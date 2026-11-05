import SwiftUI

/// Big numeric value with − / + buttons (Figma "Number Input"). Tapping the value focuses it; the
/// caller then shows a [Keypad] and feeds the typed [value] back.
struct NumberInput: View {
    let label: String
    let value: String
    let hint: String?
    let isFocused: Bool
    let onValueTap: () -> Void
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(spacing: Spacing.x8) {
            Text(label)
                .textStyle(.subhead)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: Spacing.x16) {
                RoundButton(icon: "ic_minus", label: Strings.format("stepper_decrease", label), action: onDecrease)
                Button(action: onValueTap) {
                    HStack(spacing: Spacing.x2) {
                        Text(value)
                            .textStyle(.numericLarge)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        if isFocused { Caret() }
                    }
                    .frame(width: 150, height: 64)
                    .background(Color.bgSurface2, in: .rect(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .inset(by: 1)
                            .stroke(isFocused ? Color.accentPrimary : .clear, lineWidth: 2)
                    )
                    .contentShape(.rect(cornerRadius: Radius.md))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(label)
                .accessibilityValue(value)
                RoundButton(icon: "ic_plus", label: Strings.format("stepper_increase", label), action: onIncrease)
            }
            if let hint {
                Text(hint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The blinking text cursor of a focused [NumberInput].
private struct Caret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Rectangle()
                .fill(Color.accentPrimary)
                .frame(width: 2, height: 30)
                .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
        }
    }
}

private struct RoundButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 52, height: 52)
                .background(Color.bgSurface2, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

/// Decimal number pad shown while a [NumberInput] is focused. [showsDecimal] hides "." for whole numbers.
struct Keypad: View {
    let onKey: (Character) -> Void
    let onBackspace: () -> Void
    var showsDecimal = true

    var body: some View {
        VStack(spacing: 6) {
            ForEach(["123", "456", "789"], id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(Array(row), id: \.self) { digit in
                        Key(action: { onKey(digit) }) { KeyText(String(digit)) }
                    }
                }
            }
            HStack(spacing: 6) {
                if showsDecimal {
                    Key(action: { onKey(".") }, isFilled: false) { KeyText(".") }
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 46)
                }
                Key(action: { onKey("0") }) { KeyText("0") }
                Key(action: onBackspace, isFilled: false) {
                    Image("ic_delete")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityLabel(Text("keypad_backspace"))
                }
            }
        }
        .padding(6)
        .background(Color.bgTabBar)
    }
}

private struct Key<Content: View>: View {
    let action: () -> Void
    var isFilled = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isFilled ? Color.bgSurface2 : .clear, in: .rect(cornerRadius: Radius.xs))
                .contentShape(.rect(cornerRadius: Radius.xs))
        }
        .buttonStyle(.pressable)
    }
}

private struct KeyText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(verbatim: text)
            .textStyle(.title2)
            .foregroundStyle(Color.textPrimary)
    }
}

#Preview {
    VStack(spacing: Spacing.x20) {
        NumberInput(label: "Weight, kg", value: "57.5", hint: "Last time: 55 kg", isFocused: true, onValueTap: {}, onDecrease: {}, onIncrease: {})
        NumberInput(label: "Reps", value: "8", hint: nil, isFocused: false, onValueTap: {}, onDecrease: {}, onIncrease: {})
        Keypad(onKey: { _ in }, onBackspace: {})
    }
    .background(Color.bgSurface)
}

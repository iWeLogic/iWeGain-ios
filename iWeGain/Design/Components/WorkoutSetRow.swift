import SwiftUI

/// One set of the current exercise (Figma "Workout Set Row"). Done shows the logged result with an
/// edit (pencil) button; Current and Upcoming show the target. [label] is the trailing "NOW" / "SKIPPED".
struct WorkoutSetRow: View {
    let number: Int
    let weight: String
    let reps: String
    let status: WorkoutSetStatus
    var label: LocalizedStringKey?
    /// Makes a skipped set tappable to try it again; shows a retry icon after its label.
    var onRetry: (() -> Void)?
    /// Shows a pencil button on a done set to change what was logged.
    var onEdit: (() -> Void)?

    var body: some View {
        if let onRetry {
            Button(action: onRetry) { row.contentShape(.rect) }
                .buttonStyle(.pressable)
                .accessibilityHint(Text("exercise_set_retry"))
        } else {
            row
        }
    }

    private var isCurrent: Bool { status == .current }
    private var isMuted: Bool { status == .upcoming || status == .skipped }

    private var row: some View {
        HStack(spacing: Spacing.x12) {
            Text(verbatim: "\(number)")
                .textStyle(.caption)
                .foregroundStyle(isCurrent ? Color.accentOn : isMuted ? Color.textTertiary : Color.textSecondary)
                .frame(width: 28, height: 28)
                .background(isCurrent ? Color.accentPrimary : Color.bgSurface2, in: .circle)
            Text(weight)
                .textStyle(.callout)
                .foregroundStyle(isMuted ? Color.textTertiary : Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(reps)
                .textStyle(.callout)
                .foregroundStyle(isMuted ? Color.textTertiary : Color.textSecondary)
                .lineLimit(1)
            trailing
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(isCurrent ? Color.accentSoft : .clear, in: .rect(cornerRadius: Radius.sm))
    }

    @ViewBuilder
    private var trailing: some View {
        if status == .done, let onEdit {
            Button(action: onEdit) {
                Image("ic_pencil")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("exercise_set_edit"))
        } else if let label {
            HStack(spacing: Spacing.x4) {
                Text(label)
                    .textStyle(.caption)
                    .foregroundStyle(isCurrent ? Color.accentPrimary : Color.textTertiary)
                    .lineLimit(1)
                if onRetry != nil {
                    Image("ic_repeat")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        } else {
            Color.clear.frame(width: 18, height: 18)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.x2) {
        WorkoutSetRow(number: 1, weight: "50 kg", reps: "× 8", status: .done, onEdit: {})
        WorkoutSetRow(number: 2, weight: "55 kg", reps: "× 8", status: .skipped, label: "exercise_set_skipped", onRetry: {})
        WorkoutSetRow(number: 3, weight: "60 kg", reps: "× 6", status: .current, label: "exercise_set_now")
        WorkoutSetRow(number: 4, weight: "60 kg", reps: "× 6", status: .upcoming)
    }
    .padding(Spacing.x8)
    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    .padding()
    .background(Color.bgBase)
}

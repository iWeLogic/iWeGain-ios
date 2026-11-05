import SwiftUI

/// Shown on Home while a workout is in progress; tapping it returns to the workout.
struct ActiveWorkoutBanner: View {
    let title: String
    let subtitle: String
    let elapsed: String
    let progress: Double
    let progressText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.x12) {
                HStack(spacing: Spacing.x12) {
                    IconBadge(asset: "ic_play", size: 40, iconSize: 20, cornerRadius: 12, foreground: .accentOn, background: .accentPrimary)
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text(title)
                            .textStyle(.subhead)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .textStyle(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ElapsedChip(text: elapsed, background: .accentSoft, foreground: .accentPrimary)
                }
                HStack(spacing: 10) {
                    ProgressBar(progress: progress)
                    // Tabular digits, so the rest countdown doesn't resize the line as it ticks.
                    Text(progressText)
                        .textStyle(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(14)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).inset(by: 0.75).stroke(Color.accentPrimary, lineWidth: 1.5))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        Capsule()
            .fill(Color.bgSurface2)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentPrimary)
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
            }
    }
}

#Preview {
    ActiveWorkoutBanner(title: "Push Day", subtitle: "Overhead Press · Set 2 of 3", elapsed: "24:13", progress: 0.5, progressText: "5 / 10 sets", action: {})
        .padding()
        .background(Color.bgBase)
}

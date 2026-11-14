import SwiftUI

/// Timer pill with the workout's elapsed time, e.g. "⏱ 24:13".
struct ElapsedChip: View {
    let text: String
    /// nil in a toolbar, where the system's glass bubble is the background.
    var background: Color?
    var foreground: Color = .textPrimary
    var style: AppTextStyle = .subhead

    var body: some View {
        HStack(spacing: Spacing.x4) {
            Image("ic_timer")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.accentPrimary)
            // Tabular digits: the pill keeps its width as the seconds tick.
            Text(text)
                .textStyle(style)
                .monospacedDigit()
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, background == nil ? 0 : 10)
        .padding(.vertical, background == nil ? 0 : 6)
        .background(background ?? .clear, in: .capsule)
    }
}

#Preview {
    ElapsedChip(text: "24:13", background: .bgSurface).padding().background(Color.bgBase)
}

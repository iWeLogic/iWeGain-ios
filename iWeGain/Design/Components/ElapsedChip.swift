import SwiftUI

/// Timer pill with the workout's elapsed time, e.g. "⏱ 24:13".
struct ElapsedChip: View {
    let text: String
    var background: Color = .bgSurface
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background, in: .capsule)
    }
}

#Preview {
    ElapsedChip(text: "24:13").padding().background(Color.bgBase)
}

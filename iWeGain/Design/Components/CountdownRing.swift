import SwiftUI

/// Circular countdown: the accent arc shows the time left, starting at 12 o'clock and running clockwise.
/// [progress] is read every frame through a TimelineView, so the ring moves smoothly between ticks.
struct CountdownRing: View {
    let progress: (Date) -> Double
    let label: String
    let time: String
    let caption: String
    var size: CGFloat = 168
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.bgSurface2, lineWidth: lineWidth)
            TimelineView(.animation) { context in
                Circle()
                    .trim(from: 0, to: progress(context.date))
                    .stroke(Color.accentPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: Spacing.x2) {
                Text(label)
                    .font(.custom(AppFont.medium, size: 11, relativeTo: .caption2))
                    .foregroundStyle(Color.textSecondary)
                // Smaller than numericDisplay so "10:00" fits inside the ring.
                Text(time)
                    .font(.custom(AppFont.bold, size: 48, relativeTo: .largeTitle))
                    .tracking(-1)
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .textStyle(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, lineWidth + Spacing.x8)
        }
        .padding(lineWidth / 2 + 5)
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CountdownRing(progress: { _ in 0.7 }, label: "REST", time: "1:24", caption: "of 2:00")
        .padding()
        .background(Color.bgBase)
}

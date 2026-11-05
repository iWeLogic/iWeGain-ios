import SwiftUI

/// One bar: [fraction] of the tallest bar (0 when there's nothing, drawn as a thin stub).
struct BarUi: Equatable {
    let label: String
    let fraction: Double
    let isSelected: Bool
    /// Read by VoiceOver, e.g. "Sep 28 – 30, 15,200 kg".
    let description: String
}

/// Vertical bars with a label under each; tapping a bar selects it (accent color).
struct BarChart: View {
    let bars: [BarUi]
    let onBarTap: (Int) -> Void
    var barWidth: CGFloat = 20
    var maxBarHeight: CGFloat = 118

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(bars.indices, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                bar(index)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxBarHeight + 32, alignment: .bottom)
    }

    private func bar(_ index: Int) -> some View {
        let bar = bars[index]
        return Button { onBarTap(index) } label: {
            VStack(spacing: Spacing.x8) {
                Spacer(minLength: 0)
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 6)
                    .fill(bar.isSelected ? Color.accentPrimary : Color.chartBar)
                    .frame(width: barWidth, height: bar.fraction > 0 ? max(8, maxBarHeight * bar.fraction) : 3)
                Text(bar.label)
                    .textStyle(.tabLabel)
                    .foregroundStyle(bar.isSelected ? Color.textPrimary : Color.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: barWidth)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bar.description)
        .accessibilityAddTraits(bar.isSelected ? .isSelected : [])
    }
}

#Preview {
    BarChart(
        bars: ([0.7, 0.8, 0, 0.85, 0.84, 0.92, 0.89, 0, 0.95, 1] as [Double]).enumerated().map { (index: Int, fraction: Double) -> BarUi in
            BarUi(label: String(index * 3 + 1), fraction: fraction, isSelected: index == 9, description: "")
        },
        onBarTap: { _ in }
    )
    .padding()
    .background(Color.bgSurface)
}

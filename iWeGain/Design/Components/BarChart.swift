import SwiftUI

/// One bar: [fraction] of the tallest bar (0 when there's nothing, drawn as a thin stub).
struct BarUi: Equatable {
    let label: String
    let fraction: Double
    let isSelected: Bool
    /// Read by VoiceOver, e.g. "Sep 28 – 30, 15,200 kg".
    let description: String
}

/// Vertical bars with a label under each. A bar is selected (accent color) as soon as a finger touches it,
/// and the selection follows the finger while it slides across the bars.
struct BarChart: View {
    let bars: [BarUi]
    let onBarTap: (Int) -> Void
    var barWidth: CGFloat = 20
    var maxBarHeight: CGFloat = 118

    @State private var width: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(bars.indices, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                bar(index)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxBarHeight + 32, alignment: .bottom)
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onTouchLocation { select(at: $0) }
    }

    /// Bars are spread evenly, so the bar under a finger is its share of the width.
    private func select(at x: CGFloat) {
        guard !bars.isEmpty, width > 0 else { return }
        let index = min(max(Int(x / width * CGFloat(bars.count)), 0), bars.count - 1)
        if !bars[index].isSelected { onBarTap(index) }
    }

    private func bar(_ index: Int) -> some View {
        let bar = bars[index]
        return VStack(spacing: Spacing.x8) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bar.description)
        .accessibilityAddTraits(bar.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onBarTap(index) }
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

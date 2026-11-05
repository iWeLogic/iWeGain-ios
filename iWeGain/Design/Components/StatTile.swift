import SwiftUI

/// Labelled number tile: "Sets done / 5 / 10 / 5 left". Put tiles side by side in an HStack with
/// `.fixedSize(horizontal: false, vertical: true)` and `maxHeight: .infinity` so they stay the same height.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    let caption: String
    /// Green for a good result ("+4% vs last"), grey otherwise.
    var captionColor: Color = .textSecondary
    var valueStyle: AppTextStyle = .numericLarge

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text(label)
                .textStyle(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            Text(value)
                .textStyle(valueStyle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                // Values like "2 год 35 хв" don't fit half a screen at full size.
                .minimumScaleFactor(0.5)
            Text(caption)
                .textStyle(.caption)
                .foregroundStyle(captionColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: Spacing.x12) {
        StatTile(label: "workout_sets_done", value: "5 / 10", caption: "5 left")
        StatTile(label: "workout_volume", value: "3,240 kg", caption: "This workout")
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding()
    .background(Color.bgBase)
}

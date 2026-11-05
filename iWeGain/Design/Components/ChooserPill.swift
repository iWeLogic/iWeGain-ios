import SwiftUI

/// "All trainings ▾": a full-width field showing the current choice; tapping it opens a chooser sheet.
/// Styled like the Set / Maximum [AppSegmentedControl] track inside a chart card.
struct ChooserPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x8) {
                Text(text)
                    .textStyle(.subhead)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("ic_chevron_down")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Spacing.x16)
            .frame(height: 50)
            .background(Color.bgBase, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    ChooserPill(text: "All trainings", action: {}).padding().background(Color.bgSurface)
}

import SwiftUI

/// An option with an icon, title, explanation and chevron, e.g. "Free workout" on Home.
struct OptionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: icon, size: 48, iconSize: 24)
                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text(title)
                        .textStyle(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .textStyle(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                Image("ic_chevron_right")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(Spacing.x16)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    OptionCard(icon: "ic_play", title: "free_workout", subtitle: "home_free_workout_hint", action: {})
        .padding()
        .background(Color.bgBase)
}

import SwiftUI

/// Centered picture, title and message for a screen or section without content.
struct EmptyStateView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    /// An app icon from the asset catalog (`ic_…`).
    var icon: String?

    var body: some View {
        VStack(spacing: Spacing.x12) {
            if let icon {
                IconBadge(asset: icon, size: 72, iconSize: 34, cornerRadius: Radius.xl)
            }
            Text(title)
                .textStyle(.title2)
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .textStyle(.callout)
                .foregroundStyle(Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.x24)
        .padding(.vertical, Spacing.x40)
    }
}

#Preview {
    EmptyStateView(
        title: "No trainings yet",
        message: "Create your first training: pick exercises, sets and rest time",
        icon: "ic_dumbbell"
    )
    .background(Color.bgBase)
}

import SwiftUI

/// Figma "34 · Update Required": shown instead of the app while this version is below the lowest one Remote
/// Config allows. There's no way past it but updating.
struct ForceUpdateScreen: View {
    /// The App Store search, until the app's page exists and has an id.
    private static let storeURL = URL(string: "https://apps.apple.com/search?term=iWeGain")!

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            IconBadge(asset: "ic_phone_update", size: 96, iconSize: 70, cornerRadius: Radius.xl, foreground: .accentOn, background: .accentPrimary)
            VStack(spacing: Spacing.x8) {
                Text("force_update_title").textStyle(.largeTitle).foregroundStyle(Color.textPrimary).multilineTextAlignment(.center)
                Text("force_update_message").textStyle(.callout).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.x24)
            Spacer()
            Button { openURL(Self.storeURL) } label: {
                Label { Text("force_update_button") } icon: { Image("ic_export") }
            }
            .buttonStyle(.appPrimary)
        }
        .padding(.horizontal, Spacing.x24)
        .padding(.vertical, Spacing.x16)
        .background(Color.bgBase)
    }
}

#Preview { ForceUpdateScreen() }

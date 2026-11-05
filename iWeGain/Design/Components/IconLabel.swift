import SwiftUI

/// A button label with an app icon in front: "▶ Start workout".
struct IconLabel: View {
    let text: Text
    let icon: String
    var iconSize: CGFloat = 20

    init(_ key: LocalizedStringKey, icon: String, iconSize: CGFloat = 20) {
        text = Text(key)
        self.icon = icon
        self.iconSize = iconSize
    }

    /// Text that's already worded, such as "Go to Push Day".
    init(verbatim: String, icon: String, iconSize: CGFloat = 20) {
        text = Text(verbatim)
        self.icon = icon
        self.iconSize = iconSize
    }

    var body: some View {
        Label { text } icon: { Image(icon).resizable().frame(width: iconSize, height: iconSize) }
    }
}

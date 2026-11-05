import SwiftUI

/// An icon on a tinted rounded square: training icons, exercise pictures, the empty-state picture.
struct IconBadge: View {
    let image: Image
    var size: CGFloat = 44
    var iconSize: CGFloat = 24
    var cornerRadius: CGFloat = Radius.md
    var foreground: Color = .accentPrimary
    var background: Color = .accentSoft

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}

extension IconBadge {
    /// An app icon from the asset catalog (`ic_…`, converted from Android).
    init(asset: String, size: CGFloat = 44, iconSize: CGFloat = 24, cornerRadius: CGFloat = Radius.md,
         foreground: Color = .accentPrimary, background: Color = .accentSoft) {
        self.init(image: Image(asset), size: size, iconSize: iconSize, cornerRadius: cornerRadius, foreground: foreground, background: background)
    }

    /// An SF Symbol.
    init(systemImage: String, size: CGFloat = 44, iconSize: CGFloat = 24, cornerRadius: CGFloat = Radius.md,
         foreground: Color = .accentPrimary, background: Color = .accentSoft) {
        self.init(image: Image(systemName: systemImage), size: size, iconSize: iconSize, cornerRadius: cornerRadius, foreground: foreground, background: background)
    }

    /// Exercise tile (Figma "Exercise Icons" tile): a 32 pt picture on a 56 pt tile.
    static func exercise(_ imageName: String) -> IconBadge {
        IconBadge(asset: imageName, size: 56, iconSize: 32)
    }
}

#Preview {
    HStack {
        IconBadge(asset: "ic_dumbbell")
        IconBadge.exercise("ic_ex_barbell_squat")
    }
    .padding()
    .background(Color.bgBase)
}

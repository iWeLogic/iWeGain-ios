import SwiftUI

/// The surface card the content of most screens sits on.
struct CardStyle: ViewModifier {
    var padding: CGFloat = Spacing.x16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.x16) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

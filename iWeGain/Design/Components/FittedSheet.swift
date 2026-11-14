import SwiftUI

/// The scrolling body of a sheet that is only as tall as its content (plus the navigation bar above it and anything
/// in [footer] below), up to full height, where it scrolls. Its one detent follows the content, so a short list or
/// dialog doesn't open half the screen of empty space.
struct FittedSheetScroll<Content: View, Footer: View>: View {
    private let content: Content
    private let footer: Footer

    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var insets: CGFloat = 0

    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            // The navigation bar takes part of the sheet's height too.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { insets = $0 }
            footer.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight + footerHeight + insets)] : [.medium])
    }
}

extension FittedSheetScroll where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, footer: { EmptyView() })
    }
}

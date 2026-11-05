import CoreText
import SwiftUI

/// Text styles from the Figma text styles (Inter). Each scales with Dynamic Type like the system style it's
/// relative to.
enum AppTextStyle {
    case largeTitle, title2, headline, body, callout, subhead, footnote, caption, tabLabel
    case numericDisplay, numericLarge, numericMedium

    var font: Font {
        switch self {
        case .largeTitle: .custom(AppFont.bold, size: 34, relativeTo: .largeTitle)
        case .title2: .custom(AppFont.bold, size: 22, relativeTo: .title2)
        case .headline: .custom(AppFont.semiBold, size: 17, relativeTo: .headline)
        case .body: .custom(AppFont.regular, size: 17, relativeTo: .body)
        case .callout: .custom(AppFont.regular, size: 15, relativeTo: .callout)
        case .subhead: .custom(AppFont.medium, size: 15, relativeTo: .subheadline)
        case .footnote: .custom(AppFont.regular, size: 13, relativeTo: .footnote)
        case .caption: .custom(AppFont.medium, size: 12, relativeTo: .caption)
        case .tabLabel: .custom(AppFont.medium, size: 10, relativeTo: .caption2)
        case .numericDisplay: .custom(AppFont.bold, size: 64, relativeTo: .largeTitle)
        case .numericLarge: .custom(AppFont.bold, size: 28, relativeTo: .title)
        case .numericMedium: .custom(AppFont.semiBold, size: 20, relativeTo: .title3)
        }
    }

    /// Letter spacing in points.
    var tracking: CGFloat {
        switch self {
        case .largeTitle: 0.4
        case .title2: -0.3
        case .headline, .body: -0.4
        case .callout, .subhead: -0.2
        case .footnote: -0.1
        case .caption: 0
        case .tabLabel: 0.1
        case .numericDisplay: -1.5
        case .numericLarge: -0.5
        case .numericMedium: -0.3
        }
    }
}

extension View {
    /// Applies one of the app's [AppTextStyle]s: Inter font plus its letter spacing.
    func textStyle(_ style: AppTextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

/// The bundled Inter font files (`Resources/Fonts`).
enum AppFont {
    static let regular = "Inter-Regular"
    static let medium = "Inter-Medium"
    static let semiBold = "Inter-SemiBold"
    static let bold = "Inter-Bold"

    /// Registers the fonts for this process; called once at launch, before any view is shown.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}

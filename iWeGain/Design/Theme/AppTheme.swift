import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// App-wide looks that SwiftUI can't set per view: the navigation bar titles use Inter.
enum AppTheme {
    static func configure() {
        #if canImport(UIKit)
        let appearance = UINavigationBar.appearance()
        if let largeTitle = UIFont(name: AppFont.bold, size: 34), let title = UIFont(name: AppFont.semiBold, size: 17) {
            appearance.largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: largeTitle),
                .kern: 0.4
            ]
            appearance.titleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title),
                .kern: -0.4
            ]
        }
        #endif
    }
}

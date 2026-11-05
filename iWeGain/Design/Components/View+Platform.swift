import SwiftUI

extension View {
    /// The small centered title of pushed screens (iOS); the Mac has only one kind.
    func inlineNavigationTitle() -> some View {
        #if os(iOS) || os(visionOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Hides the navigation bar of a tab's first screen that has no title (Home).
    func hidesNavigationBar() -> some View {
        #if os(iOS) || os(visionOS)
        toolbarVisibility(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Hides the tab bar while this screen is shown (pushed editors and pickers), like Android.
    func hidesTabBar() -> some View {
        #if os(iOS)
        toolbarVisibility(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    /// Keeps the display awake while this screen is shown (the workout screens), like Android's KeepScreenOn.
    func keepsScreenOn() -> some View {
        #if os(iOS)
        onAppear { ScreenAwake.acquire() }
            .onDisappear { ScreenAwake.release() }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Counts the visible screens that keep the display awake: pushing the exercise over the workout
/// overview makes the overview disappear after the exercise appears, so a plain flag would turn it off.
private enum ScreenAwake {
    static var count = 0

    static func acquire() {
        count += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func release() {
        count = max(0, count - 1)
        if count == 0 { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
#endif

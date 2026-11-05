import CoreText
import SwiftUI

/// The companion of the phone app: shows the phone's running workout and logs sets on it.
@main
struct iWeGainWatchApp: App {
    @State private var viewModel: WatchWorkoutViewModel

    init() {
        let fonts = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
        #if DEBUG
        let link: PhoneLink = DebugPhoneLink.fromLaunchArguments() ?? PhoneConnection()
        #else
        let link: PhoneLink = PhoneConnection()
        #endif
        _viewModel = State(initialValue: WatchWorkoutViewModel(link: link))
    }

    var body: some Scene {
        WindowGroup {
            WatchWorkoutScreen(state: viewModel.state, onAction: viewModel.onAction)
                .task { viewModel.start() }
        }
    }
}

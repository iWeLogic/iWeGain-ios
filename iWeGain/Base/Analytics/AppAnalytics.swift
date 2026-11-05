import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation

/// Firebase Analytics and Crashlytics. Does nothing without Firebase; debug builds don't collect anything.
final class AppAnalytics {
    private let authRepository: AuthRepository
    private var task: Task<Void, Never>?

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    /// Tags events and crash reports with the signed-in user's id (none for a guest).
    func start() {
        guard task == nil, AppFirebase.isConfigured else { return }
        #if DEBUG
        Analytics.setAnalyticsCollectionEnabled(false)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
        task = Task { [authRepository] in
            for await uid in authRepository.observeUser().map({ $0?.id }).removeDuplicates() {
                Analytics.setUserID(uid)
                Crashlytics.crashlytics().setUserID(uid)
            }
        }
    }

    /// Automatic screen reporting is off (Info.plist), so screens are logged by hand from the navigation.
    func logScreen(_ name: String) {
        guard AppFirebase.isConfigured else { return }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: name, AnalyticsParameterScreenClass: name])
        Crashlytics.crashlytics().log("Screen: \(name)")
    }
}

extension AppContainer {
    var analytics: AppAnalytics { shared { AppAnalytics(authRepository: authRepository) } }
}

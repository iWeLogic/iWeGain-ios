import SwiftUI
import UserNotifications

@main
struct iWeGainApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: PushAppDelegate
    #endif
    private let container: AppContainer
    #if os(iOS)
    /// Follows the active workout for the whole app run; its buttons work even with the app in the background.
    private let liveActivity: WorkoutLiveActivityManager
    #endif
    private let restSounds: WorkoutRestSounds
    private let reminders: ReminderScheduler
    private let notificationDelegate = AppNotificationDelegate()

    init() {
        AppFont.register()
        AppTheme.configure()
        AppFirebase.configureIfPossible()
        // UI tests start from an empty in-memory database.
        let isUiTesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        container = isUiTesting ? .inMemory() : .live()
        #if DEBUG
        DebugLaunch.seedIfRequested(container)
        #endif
        #if os(iOS)
        liveActivity = container.makeWorkoutLiveActivityManager()
        liveActivity.start()
        #endif
        restSounds = container.makeWorkoutRestSounds()
        restSounds.start()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        reminders = container.makeReminderScheduler()
        container.backgroundSync.register()
        container.backgroundSync.schedule()
        container.analytics.start()
        container.appUpdateRepository.start()
        container.settingsRepository.start()
        container.profileRepository.start()
        container.pushRepository.start()
        container.syncManager.start()
        // UI tests shouldn't be stopped by the permission prompt.
        if !isUiTesting { reminders.start() }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(container: container)
                #if os(iOS)
                .onAppear {
                    appDelegate.pushRepository = container.pushRepository
                    appDelegate.syncManager = container.syncManager
                }
                #endif
        }
    }
}

/// The app's content in the colors chosen in Settings: the splash screen until the signed-in person's data has
/// loaded (or failed to: the header then shows "Offline"), and nothing but the update screen when this version
/// is too old.
private struct AppRoot: View {
    private static let splashMinimum: Duration = .seconds(2)

    let container: AppContainer
    @State private var themeMode: ThemeMode = .dark
    @State private var isUpdateRequired = false
    @State private var isSplashVisible = !ProcessInfo.processInfo.arguments.contains("-ui-testing")

    var body: some View {
        ZStack {
            if isUpdateRequired {
                ForceUpdateScreen()
            } else {
                AppNavigation(container: container)
                if isSplashVisible {
                    SplashView().transition(.opacity)
                }
            }
        }
        .preferredColorScheme(themeMode.colorScheme)
        .task {
            for await settings in container.settingsRepository.observeSettings() { themeMode = settings.themeMode }
        }
        .task {
            for await required in container.appUpdateRepository.observeUpdateRequired() { isUpdateRequired = required }
        }
        .task {
            guard isSplashVisible else { return }
            async let minimum: Void? = try? Task.sleep(for: Self.splashMinimum)
            for await status in container.syncManager.observeStatus() where status != .loading { break }
            _ = await minimum
            withAnimation { isSplashVisible = false }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        IconBadge(asset: "ic_dumbbell", size: 88, iconSize: 44, cornerRadius: 24, foreground: .accentOn, background: .accentPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgBase)
    }
}

private extension ThemeMode {
    /// nil follows the phone's own setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

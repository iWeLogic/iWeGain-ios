import FirebaseRemoteConfig
import Foundation

/// Whether this version is too old to keep using: Remote Config's [minBuildKey] holds the lowest iOS build
/// number still allowed. It's fetched on start and follows real-time updates; offline the last fetched value
/// applies, and without one (or without Firebase) nothing is blocked.
final class AppUpdateRepository {
    /// Remote Config parameter: the lowest iOS build number that may still be used.
    static let minBuildKey = "ios_min_build_number"
    private static let fetchInterval: TimeInterval = 3600

    private let updateRequired = StateStream(false)
    private var isStarted = false
    private var listener: ConfigUpdateListenerRegistration?

    func observeUpdateRequired() -> AsyncStream<Bool> { updateRequired.stream() }

    func start() {
        guard !isStarted, AppFirebase.isConfigured else { return }
        isStarted = true
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = Self.fetchInterval
        #endif
        config.configSettings = settings
        config.setDefaults([Self.minBuildKey: NSNumber(value: 0)])
        // The value activated last time applies right away, before the fetch finishes.
        publish()
        Task { [self] in
            _ = try? await config.fetchAndActivate()
            publish()
        }
        // Real-time updates are a bonus: the next start fetches anyway.
        listener = config.addOnConfigUpdateListener { @Sendable update, _ in
            guard update?.updatedKeys.contains(Self.minBuildKey) == true else { return }
            Task { @MainActor [weak self] in
                _ = try? await RemoteConfig.remoteConfig().activate()
                self?.publish()
            }
        }
    }

    private func publish() {
        let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
        updateRequired.send(build < RemoteConfig.remoteConfig().configValue(forKey: Self.minBuildKey).numberValue.intValue)
    }
}

extension AppContainer {
    var appUpdateRepository: AppUpdateRepository { shared { AppUpdateRepository() } }
}

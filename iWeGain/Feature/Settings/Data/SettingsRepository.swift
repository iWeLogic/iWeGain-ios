import Foundation

/// App preferences, kept on the device. While signed in, each change is also saved to the account, and the
/// account's settings replace this device's once per sign-in.
final class SettingsRepository {
    private static let initialBackoff: Duration = .seconds(5)
    private static let maxBackoff: Duration = .seconds(5 * 60)

    private let local: SettingsLocalDataSource
    private let authRepository: AuthRepository
    private let remote: SettingsRemoteDataSource
    private var startTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?

    init(local: SettingsLocalDataSource, authRepository: AuthRepository, remote: SettingsRemoteDataSource) {
        self.local = local
        self.authRepository = authRepository
        self.remote = remote
    }

    func observeSettings() -> AsyncStream<AppSettings> { local.observeSettings() }

    var settings: AppSettings { local.settings() }

    /// Restores the account's settings on every sign-in (and on app start until that has worked once).
    func start() {
        guard startTask == nil else { return }
        startTask = Task { [self] in
            for await uid in authRepository.observeUser().map({ $0?.id }).removeDuplicates() {
                restoreTask?.cancel()
                guard let uid else { continue }
                restoreTask = Task { await restore(uid: uid) }
            }
        }
    }

    /// After signing out, so the next sign-in restores the account's settings again.
    func forgetAccount() { local.restoredFor = nil }

    func setWeightUnit(_ unit: WeightUnit) {
        local.setWeightUnit(unit)
        saveToAccount(["weightUnit": unit.rawValue])
    }

    func setDefaultRestSeconds(_ seconds: Int) {
        local.setDefaultRestSeconds(seconds)
        saveToAccount(["defaultRestSeconds": seconds])
    }

    /// [syncToAccount] is false when this device's notification permission decides it: that answer belongs to
    /// the device, not to the account's other devices.
    func setWorkoutReminders(_ enabled: Bool, syncToAccount: Bool = true) {
        local.setWorkoutReminders(enabled)
        if syncToAccount { saveToAccount(["workoutReminders": enabled]) }
    }

    func setReminderMinutesBefore(_ minutes: Int) {
        local.setReminderMinutesBefore(minutes)
        saveToAccount(["reminderMinutesBefore": minutes])
    }

    func setThemeMode(_ mode: ThemeMode) {
        local.setThemeMode(mode)
        saveToAccount(["themeMode": mode.rawValue])
    }

    private func saveToAccount(_ fields: [String: Any]) {
        if let uid = authRepository.currentUser?.id { remote.save(uid: uid, fields: fields) }
    }

    /// Applies the account's settings to this device, or uploads this device's when the account has none yet
    /// (a first sign-in keeps what was chosen as the guest). Retries until the server answers.
    private func restore(uid: String) async {
        var backoff = Self.initialBackoff
        while local.restoredFor != uid, !Task.isCancelled {
            do {
                if let saved = try await remote.fetch(uid: uid) {
                    apply(saved)
                } else {
                    let current = local.settings()
                    remote.save(uid: uid, fields: [
                        "weightUnit": current.weightUnit.rawValue,
                        "defaultRestSeconds": current.defaultRestSeconds,
                        "workoutReminders": current.workoutReminders,
                        "reminderMinutesBefore": current.reminderMinutesBefore,
                        "themeMode": current.themeMode.rawValue,
                    ])
                }
                local.restoredFor = uid
            } catch {
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, Self.maxBackoff)
            }
        }
    }

    private func apply(_ saved: SettingsFields) {
        if let value = saved.weightUnit { local.setWeightUnit(value) }
        if let value = saved.defaultRestSeconds { local.setDefaultRestSeconds(value) }
        if let value = saved.workoutReminders { local.setWorkoutReminders(value) }
        if let value = saved.reminderMinutesBefore { local.setReminderMinutesBefore(value) }
        if let value = saved.themeMode { local.setThemeMode(value) }
    }
}

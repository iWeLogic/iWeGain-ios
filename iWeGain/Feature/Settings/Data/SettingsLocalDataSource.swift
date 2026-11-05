import Foundation

/// Settings in UserDefaults, under the same keys Android's DataStore uses.
final class SettingsLocalDataSource: BaseDataSource {
    private let defaults: UserDefaults
    private let store: LocalStore

    init(defaults: UserDefaults, store: LocalStore) {
        self.defaults = defaults
        self.store = store
    }

    func observeSettings() -> AsyncStream<AppSettings> {
        observe(store) { [self] in settings() }
    }

    func settings() -> AppSettings {
        let fallback = AppSettings()
        return AppSettings(
            weightUnit: defaults.string(forKey: Keys.weightUnit).flatMap(WeightUnit.init(rawValue:)) ?? fallback.weightUnit,
            defaultRestSeconds: defaults.object(forKey: Keys.defaultRestSeconds) as? Int ?? fallback.defaultRestSeconds,
            workoutReminders: defaults.object(forKey: Keys.workoutReminders) as? Bool ?? fallback.workoutReminders,
            reminderMinutesBefore: defaults.object(forKey: Keys.reminderMinutesBefore) as? Int ?? fallback.reminderMinutesBefore,
            themeMode: defaults.string(forKey: Keys.themeMode).flatMap(ThemeMode.init(rawValue:)) ?? fallback.themeMode
        )
    }

    func setWeightUnit(_ unit: WeightUnit) { write(unit.rawValue, Keys.weightUnit) }
    func setDefaultRestSeconds(_ seconds: Int) { write(seconds, Keys.defaultRestSeconds) }
    func setWorkoutReminders(_ enabled: Bool) { write(enabled, Keys.workoutReminders) }
    func setReminderMinutesBefore(_ minutes: Int) { write(minutes, Keys.reminderMinutesBefore) }
    func setThemeMode(_ mode: ThemeMode) { write(mode.rawValue, Keys.themeMode) }

    /// The account whose settings this device has already restored.
    var restoredFor: String? {
        get { defaults.string(forKey: Keys.restoredFor) }
        set { defaults.set(newValue, forKey: Keys.restoredFor) }
    }

    private func write(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        store.notifyChanged()
    }

    private enum Keys {
        static let weightUnit = "weight_unit"
        static let defaultRestSeconds = "default_rest_seconds"
        static let workoutReminders = "workout_reminders"
        static let reminderMinutesBefore = "reminder_minutes_before"
        static let themeMode = "theme_mode"
        static let restoredFor = "settings_restored_for"
    }
}

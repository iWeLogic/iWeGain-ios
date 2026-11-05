/// User preferences from the Settings screen.
nonisolated struct AppSettings: Hashable, Sendable {
    var weightUnit: WeightUnit = .kg
    /// Rest between sets given to newly added exercises.
    var defaultRestSeconds = 180
    var workoutReminders = true
    /// How long before a scheduled training the reminder comes; 0 is at its start.
    var reminderMinutesBefore = 30
    var themeMode: ThemeMode = .dark
}

/// Light or dark colors, or the phone's own setting ([system]). Raw values are what Android and Firestore store.
nonisolated enum ThemeMode: String, CaseIterable, Codable, Sendable {
    case system = "System", light = "Light", dark = "Dark"
}


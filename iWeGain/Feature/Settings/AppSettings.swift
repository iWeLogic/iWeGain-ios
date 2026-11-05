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

nonisolated enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg = "Kg", lb = "Lb"

    private static let lbPerKg = 2.20462

    /// Converts kilograms (how weights are stored) to this unit.
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg * Self.lbPerKg }

    func toKg(_ value: Double) -> Double { self == .kg ? value : value / Self.lbPerKg }

    /// Step of the − / + weight buttons.
    var step: Double { self == .kg ? 0.25 : 0.5 }
}

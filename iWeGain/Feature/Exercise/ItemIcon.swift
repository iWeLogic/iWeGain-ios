/// Icons a user can pick for a training or a custom exercise, in the order of the icon picker grid.
/// Raw values are what Android and Firestore store.
nonisolated enum ItemIcon: String, CaseIterable, Codable, Sendable {
    case dumbbell = "Dumbbell", flame = "Flame", zap = "Zap", heart = "Heart", activity = "Activity"
    case target = "Target", trophy = "Trophy", medal = "Medal", star = "Star", flag = "Flag"
    case mountain = "Mountain", bike = "Bike", footprints = "Footprints", waves = "Waves", ball = "Ball"
    case timer = "Timer", `repeat` = "Repeat", trending = "Trending", battery = "Battery", shield = "Shield"
    case sun = "Sun", moon = "Moon", droplet = "Droplet", scale = "Scale", music = "Music"

    /// The asset (converted from the Android drawable of the same name).
    var imageName: String { "ic_\(rawValue.lowercased())" }

    /// Unknown values (from a newer app version) fall back to the dumbbell.
    init(storedValue: String) {
        self = ItemIcon(rawValue: storedValue) ?? .dumbbell
    }
}

import Foundation

nonisolated struct Exercise: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var icon: ItemIcon = .dumbbell
    /// A built-in exercise's own picture (an asset name), shown instead of [icon]; see [imageName].
    var builtInImage: String?
    /// Created by the user rather than shipped in the built-in library.
    var isCustom = false
    /// The person a custom exercise belongs to; nil for built-in ones, which everyone shares.
    var userId: String?

    /// The picture shown for the exercise: a built-in one's own, otherwise the icon picked for it.
    var imageName: String { builtInImage ?? icon.imageName }
}

/// Order matches the library filter chips. Raw values are what Android and Firestore store.
nonisolated enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest = "Chest", back = "Back", legs = "Legs", shoulders = "Shoulders", arms = "Arms", core = "Core", fullBody = "FullBody"

    var label: LocalizedStringResource {
        switch self {
        case .chest: "muscle_chest"
        case .back: "muscle_back"
        case .legs: "muscle_legs"
        case .shoulders: "muscle_shoulders"
        case .arms: "muscle_arms"
        case .core: "muscle_core"
        case .fullBody: "muscle_full_body"
        }
    }
}

nonisolated enum Equipment: String, CaseIterable, Codable, Sendable {
    case barbell = "Barbell", dumbbells = "Dumbbells", cable = "Cable", machine = "Machine", kettlebell = "Kettlebell", bodyweight = "Bodyweight"

    var label: LocalizedStringResource {
        switch self {
        case .barbell: "equipment_barbell"
        case .dumbbells: "equipment_dumbbells"
        case .cable: "equipment_cable"
        case .machine: "equipment_machine"
        case .kettlebell: "equipment_kettlebell"
        case .bodyweight: "equipment_bodyweight"
        }
    }
}

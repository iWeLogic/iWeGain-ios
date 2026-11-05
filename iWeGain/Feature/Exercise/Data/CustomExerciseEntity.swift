import Foundation
import SwiftData

/// A custom exercise created by the user (Android's `custom_exercises` table).
@Model
final class CustomExerciseEntity {
    @Attribute(.unique) var id: String
    /// Each person has their own custom exercises.
    var userId: String
    var name: String
    var muscleGroup: String
    var equipment: String
    var icon: String
    /// Epoch millis of the last change, made here or on another device; the newer copy wins when syncing.
    var updatedAt: Int64
    /// Changed on this device and not uploaded to Firestore yet.
    var isDirty: Bool

    init(id: String, userId: String, name: String, muscleGroup: String, equipment: String, icon: String, updatedAt: Int64, isDirty: Bool = true) {
        self.id = id
        self.userId = userId
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.icon = icon
        self.updatedAt = updatedAt
        self.isDirty = isDirty
    }

    func toExercise() -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: MuscleGroup(rawValue: muscleGroup) ?? .fullBody,
            equipment: Equipment(rawValue: equipment) ?? .bodyweight,
            icon: ItemIcon(storedValue: icon),
            isCustom: true,
            userId: userId
        )
    }

    /// Copies [exercise]'s fields into this row and queues it for upload.
    func update(from exercise: Exercise, updatedAt: Int64) {
        name = exercise.name
        muscleGroup = exercise.muscleGroup.rawValue
        equipment = exercise.equipment.rawValue
        icon = exercise.icon.rawValue
        self.updatedAt = updatedAt
        isDirty = true
    }
}

import Foundation
import SwiftData

/// Android's `trainings` table; its exercises are the `training_exercises` rows.
@Model
final class TrainingEntity {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var icon: String
    /// Epoch millis; trainings are listed in the order they were created.
    var createdAt: Int64
    /// Deleted; kept as a tombstone so the deletion reaches other devices. Its exercises are removed.
    var isDeleted: Bool
    /// Epoch millis of the last change, made here or on another device; the newer copy wins when syncing.
    var updatedAt: Int64
    /// Changed on this device and not uploaded to Firestore yet.
    var isDirty: Bool
    @Relationship(deleteRule: .cascade, inverse: \TrainingExerciseEntity.training)
    var exercises: [TrainingExerciseEntity] = []

    init(id: String, userId: String, name: String, icon: String, createdAt: Int64, isDeleted: Bool = false, updatedAt: Int64, isDirty: Bool = true) {
        self.id = id
        self.userId = userId
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
        self.isDirty = isDirty
    }

    /// Exercises are stored by id; [library] resolves them. Entries whose exercise no longer exists are left out.
    func toTraining(library: [String: Exercise]) -> Training {
        Training(
            id: id,
            userId: userId,
            name: name,
            icon: ItemIcon(storedValue: icon),
            exercises: exercises.sorted { $0.position < $1.position }.compactMap { entry in
                library[entry.exerciseId].map { TrainingExercise(exercise: $0, sets: entry.sets, restSeconds: entry.restSeconds) }
            }
        )
    }
}

/// One exercise of a training, at [position] in the order the user arranged them.
@Model
final class TrainingExerciseEntity {
    var position: Int
    var exerciseId: String
    var sets: Int
    var restSeconds: Int
    var training: TrainingEntity?

    init(position: Int, exerciseId: String, sets: Int, restSeconds: Int) {
        self.position = position
        self.exerciseId = exerciseId
        self.sets = sets
        self.restSeconds = restSeconds
    }
}

import Foundation
import SwiftData

/// Android's `workouts` table; [finishedAt] is nil for the one in progress. The rest fields are all set or all nil.
@Model
final class WorkoutEntity {
    @Attribute(.unique) var id: String
    var userId: String
    /// Empty for a free workout (also on Android and in Firestore).
    var trainingId: String
    var trainingName: String
    var trainingIcon: String
    /// Epoch millis; -1 for a free workout that isn't started yet.
    var startedAt: Int64
    var finishedAt: Int64?
    var restEndsAt: Int64?
    var restDurationSeconds: Int?
    var restExerciseIndex: Int?
    var restSetIndex: Int?
    var restPausedAt: Int64?
    var setsDoneAt: Int64?
    /// Deleted; kept as a tombstone so the deletion reaches other devices. Its exercises and sets are removed.
    var isDeleted: Bool
    /// Epoch millis of the last change, made here or on another device; the newer copy wins when syncing.
    var updatedAt: Int64
    /// Changed on this device and not uploaded to Firestore yet.
    var isDirty: Bool
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.workout)
    var exercises: [WorkoutExerciseEntity] = []

    init(id: String, userId: String, updatedAt: Int64) {
        self.id = id
        self.userId = userId
        trainingId = ""
        trainingName = ""
        trainingIcon = ItemIcon.dumbbell.rawValue
        startedAt = 0
        isDeleted = false
        self.updatedAt = updatedAt
        isDirty = true
    }

    /// Replaces every field and the exercise list with [workout]'s and queues it for upload.
    func update(from workout: Workout, updatedAt: Int64, context: ModelContext) {
        userId = workout.userId
        trainingId = workout.trainingId ?? ""
        trainingName = workout.trainingName
        trainingIcon = workout.trainingIcon.rawValue
        startedAt = workout.startedAt.epochMillis
        finishedAt = workout.finishedAt?.epochMillis
        restEndsAt = workout.rest?.endsAt.epochMillis
        restDurationSeconds = workout.rest?.durationSeconds
        restExerciseIndex = workout.rest?.savedExerciseIndex
        restSetIndex = workout.rest?.savedSetIndex
        restPausedAt = workout.rest?.pausedAt?.epochMillis
        setsDoneAt = workout.setsDoneAt?.epochMillis
        self.updatedAt = updatedAt
        isDirty = true
        exercises.forEach { context.delete($0) }
        exercises = workout.exercises.enumerated().map { position, exercise in WorkoutExerciseEntity(position: position, exercise: exercise) }
    }

    func toWorkout() -> Workout {
        var rest: RestTimer?
        if let restEndsAt, let restDurationSeconds, let restExerciseIndex, let restSetIndex {
            rest = RestTimer(
                endsAt: Date(epochMillis: restEndsAt),
                durationSeconds: restDurationSeconds,
                savedExerciseIndex: restExerciseIndex,
                savedSetIndex: restSetIndex,
                pausedAt: restPausedAt.map(Date.init(epochMillis:))
            )
        }
        return Workout(
            id: id,
            userId: userId,
            trainingId: trainingId.isEmpty ? nil : trainingId,
            trainingName: trainingName,
            trainingIcon: ItemIcon(storedValue: trainingIcon),
            startedAt: Date(epochMillis: startedAt),
            finishedAt: finishedAt.map(Date.init(epochMillis:)),
            exercises: exercises.sorted { $0.position < $1.position }.map { $0.toWorkoutExercise() },
            rest: rest,
            setsDoneAt: setsDoneAt.map(Date.init(epochMillis:))
        )
    }
}

/// An exercise of a workout. It keeps a copy of the exercise as it was, so history doesn't change
/// when a custom exercise is edited later.
@Model
final class WorkoutExerciseEntity {
    var position: Int
    var exerciseId: String
    var name: String
    var muscleGroup: String
    var equipment: String
    var icon: String
    var isCustom: Bool
    var restSeconds: Int
    var isSkipped: Bool
    var startedAt: Int64?
    var workout: WorkoutEntity?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetEntity.exercise)
    var sets: [WorkoutSetEntity] = []

    init(position: Int, exercise entry: WorkoutExercise) {
        self.position = position
        exerciseId = entry.exercise.id
        name = entry.exercise.name
        muscleGroup = entry.exercise.muscleGroup.rawValue
        equipment = entry.exercise.equipment.rawValue
        icon = entry.exercise.icon.rawValue
        isCustom = entry.exercise.isCustom
        restSeconds = entry.restSeconds
        isSkipped = entry.isSkipped
        startedAt = entry.startedAt?.epochMillis
        sets = entry.sets.enumerated().map { WorkoutSetEntity(position: $0, set: $1) }
    }

    func toWorkoutExercise() -> WorkoutExercise {
        WorkoutExercise(
            exercise: Exercise(
                id: exerciseId,
                name: name,
                muscleGroup: MuscleGroup(rawValue: muscleGroup) ?? .fullBody,
                equipment: Equipment(rawValue: equipment) ?? .bodyweight,
                icon: ItemIcon(storedValue: icon),
                isCustom: isCustom
            ),
            restSeconds: restSeconds,
            sets: sets.sorted { $0.position < $1.position }.map { $0.toWorkoutSet() },
            isSkipped: isSkipped,
            startedAt: startedAt.map(Date.init(epochMillis:))
        )
    }
}

@Model
final class WorkoutSetEntity {
    var position: Int
    var status: String
    var targetWeightKg: Double
    var targetReps: Int
    var weightKg: Double?
    var reps: Int?
    var exercise: WorkoutExerciseEntity?

    init(position: Int, set: WorkoutSet) {
        self.position = position
        status = set.status.rawValue
        targetWeightKg = set.targetWeightKg
        targetReps = set.targetReps
        weightKg = set.weightKg
        reps = set.reps
    }

    func toWorkoutSet() -> WorkoutSet {
        WorkoutSet(
            status: SetStatus(rawValue: status) ?? .pending,
            targetWeightKg: targetWeightKg,
            targetReps: targetReps,
            weightKg: weightKg,
            reps: reps
        )
    }
}

import Foundation

/// The exercise library: built-in exercises plus each person's own custom ones, which are stored in SwiftData.
final class ExerciseRepository {
    private let local: ExerciseLocalDataSource

    init(local: ExerciseLocalDataSource) {
        self.local = local
    }

    /// What [userId] can pick from: the built-in exercises plus their own custom ones.
    func observeExercises(userId: String) -> AsyncStream<[Exercise]> {
        local.observeCustomExercises(userId: userId).map { BuiltInExercises.library() + $0 }
    }

    /// Built-in plus everyone's custom exercises, to resolve the ones trainings refer to.
    func observeAllExercises() -> AsyncStream<[Exercise]> {
        local.observeCustomExercises(userId: nil).map { BuiltInExercises.library() + $0 }
    }

    /// Built-in plus everyone's custom exercises, read once.
    func allExercises() throws(DataError) -> [Exercise] {
        BuiltInExercises.library() + (try local.customExercises(userId: nil))
    }

    /// A built-in or custom exercise, or nil when there is none with [id] (or it can't be read).
    func exercise(id: String) -> Exercise? {
        BuiltInExercises.exercise(id: id) ?? (try? local.customExercise(id: id)) ?? nil
    }

    func createExercise(
        userId: String,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        icon: ItemIcon
    ) throws(DataError) -> Exercise {
        let exercise = Exercise(
            id: UUID().uuidString.lowercased(),
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            icon: icon,
            isCustom: true,
            userId: userId
        )
        try local.save(exercise)
        return exercise
    }

    func updateExercise(_ exercise: Exercise) throws(DataError) {
        try local.save(exercise)
    }
}

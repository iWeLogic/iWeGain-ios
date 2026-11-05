nonisolated struct Training: Identifiable, Hashable, Sendable {
    let id: String
    var userId: String
    var name: String
    var icon: ItemIcon
    /// In the order the user arranged them.
    var exercises: [TrainingExercise]

    var exerciseCount: Int { exercises.count }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets } }
}

/// One exercise inside a training: how many sets and how long to rest between them.
nonisolated struct TrainingExercise: Hashable, Sendable {
    var exercise: Exercise
    var sets: Int
    var restSeconds: Int
}

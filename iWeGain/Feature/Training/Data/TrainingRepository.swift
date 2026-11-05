/// The user's trainings, stored in SwiftData and synced by `TrainingSyncDataSource`.
final class TrainingRepository {
    private let local: TrainingLocalDataSource
    private let schedule: ScheduleLocalDataSource
    private let exerciseRepository: ExerciseRepository

    init(local: TrainingLocalDataSource, schedule: ScheduleLocalDataSource, exerciseRepository: ExerciseRepository) {
        self.local = local
        self.schedule = schedule
        self.exerciseRepository = exerciseRepository
    }

    func observeTrainings(userId: String) -> AsyncStream<[Training]> {
        local.observeTrainings(userId: userId, library: { [exerciseRepository] in try exerciseRepository.allExercises() })
    }

    func training(id: String) throws(DataError) -> Training? {
        try local.training(id: id, library: exerciseRepository.allExercises())
    }

    func allTrainings() throws(DataError) -> [Training] {
        try local.allTrainings(library: exerciseRepository.allExercises())
    }

    /// Adds a new training, or replaces an existing one with the same id in place.
    func saveTraining(_ training: Training) throws(DataError) {
        try local.save(training)
    }

    /// Deletes the training and its planned sessions, also on the person's other devices. Finished
    /// workouts keep their own copy of it, so history and statistics stay.
    func deleteTraining(id: String) throws(DataError) {
        try schedule.deleteForTraining(trainingId: id)
        try local.delete(id: id)
    }
}

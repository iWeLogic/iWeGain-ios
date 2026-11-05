extension AppContainer {
    var trainingRepository: TrainingRepository {
        TrainingRepository(
            local: TrainingLocalDataSource(store: store),
            schedule: ScheduleLocalDataSource(store: store),
            exerciseRepository: exerciseRepository
        )
    }

    func makeTrainingViewModel(trainingId: String?) -> TrainingViewModel {
        TrainingViewModel(
            trainingId: trainingId,
            trainingRepository: trainingRepository,
            exerciseRepository: exerciseRepository,
            userRepository: userRepository,
            settingsRepository: settingsRepository,
            workoutRepository: workoutRepository
        )
    }
}

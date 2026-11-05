extension AppContainer {
    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(
            userRepository: userRepository,
            syncManager: syncManager,
            workoutRepository: workoutRepository,
            trainingRepository: trainingRepository,
            settingsRepository: settingsRepository,
            now: store.now
        )
    }
}

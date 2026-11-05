extension AppContainer {
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            userRepository: userRepository,
            syncManager: syncManager,
            trainingRepository: trainingRepository,
            workoutRepository: workoutRepository,
            now: store.now
        )
    }
}

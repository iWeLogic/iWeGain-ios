extension AppContainer {
    var exerciseRepository: ExerciseRepository {
        ExerciseRepository(local: ExerciseLocalDataSource(store: store))
    }

    func makeExerciseLibraryViewModel() -> ExerciseLibraryViewModel {
        ExerciseLibraryViewModel(exerciseRepository: exerciseRepository, userRepository: userRepository)
    }
}

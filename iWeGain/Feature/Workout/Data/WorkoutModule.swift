#if os(iOS)
import UIKit
#endif

extension AppContainer {
    var workoutRepository: WorkoutRepository {
        WorkoutRepository(
            local: WorkoutLocalDataSource(store: store),
            userRepository: userRepository,
            trainingRepository: trainingRepository,
            settingsRepository: settingsRepository,
            now: store.now
        )
    }

    func makeWorkoutRestSounds() -> WorkoutRestSounds {
        let sounds = SoundEffects()
        return WorkoutRestSounds(
            workoutRepository: workoutRepository,
            play: { sounds.play($0) },
            isAppActive: {
                #if os(iOS)
                UIApplication.shared.applicationState == .active
                #else
                true
                #endif
            },
            now: store.now
        )
    }

    #if os(iOS)
    func makeWatchSync() -> WatchSync {
        WatchSync(workoutRepository: workoutRepository, settingsRepository: settingsRepository, now: store.now)
    }
    #endif

    func makeWorkoutViewModel() -> WorkoutViewModel {
        WorkoutViewModel(
            workoutRepository: workoutRepository,
            exerciseRepository: exerciseRepository,
            settingsRepository: settingsRepository,
            now: store.now
        )
    }

    func makeExerciseViewModel(exerciseIndex: Int, opensLogSet: Bool = false) -> ExerciseViewModel {
        ExerciseViewModel(
            exerciseIndex: exerciseIndex,
            opensLogSet: opensLogSet,
            workoutRepository: workoutRepository,
            settingsRepository: settingsRepository,
            now: store.now
        )
    }
}

#if os(iOS)
extension AppContainer {
    func makeWorkoutLiveActivityManager() -> WorkoutLiveActivityManager {
        WorkoutLiveActivityManager(workoutRepository: workoutRepository, settingsRepository: settingsRepository, now: store.now)
    }
}
#endif

extension AppContainer {
    func makeWorkoutDetailsViewModel(workoutId: String) -> WorkoutDetailsViewModel {
        WorkoutDetailsViewModel(workoutId: workoutId, workoutRepository: workoutRepository, settingsRepository: settingsRepository)
    }

    func makeEditWorkoutViewModel(workoutId: String) -> EditWorkoutViewModel {
        EditWorkoutViewModel(
            workoutId: workoutId, workoutRepository: workoutRepository,
            exerciseRepository: exerciseRepository, settingsRepository: settingsRepository
        )
    }
}

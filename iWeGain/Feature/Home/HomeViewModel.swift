import Foundation

/// Home: the person switcher, the selected person's trainings, the running workout's banner and "Free workout".
final class HomeViewModel: BaseViewModel<HomeState, HomeAction, HomeEvent> {
    private let userRepository: UserRepository
    private let syncManager: SyncManager
    private let trainingRepository: TrainingRepository
    private let workoutRepository: WorkoutRepository
    private let now: () -> Date
    private var isObserving = false
    private var workout: Workout?

    init(userRepository: UserRepository, syncManager: SyncManager, trainingRepository: TrainingRepository, workoutRepository: WorkoutRepository, now: @escaping () -> Date) {
        self.userRepository = userRepository
        self.syncManager = syncManager
        self.trainingRepository = trainingRepository
        self.workoutRepository = workoutRepository
        self.now = now
        super.init(initialState: HomeState())
    }

    override func onAction(_ action: HomeAction) {
        switch action {
        case .onAppear: observe()
        case .onUserTap(let id): userRepository.selectUser(id)
        case .onCreateProfileTap: sendEvent(.navigateToCreateProfile)
        case .onInviteTap: sendEvent(.navigateToInvite)
        case .onTrainingTap(let id): sendEvent(.navigateToTraining(id: id))
        case .onAddTrainingTap: sendEvent(.navigateToNewTraining)
        case .onFreeWorkoutTap:
            // Offered only while nothing runs, so another workout can't be in the way.
            if (try? workoutRepository.startFreeWorkout()) != nil { sendEvent(.navigateToWorkout(restExerciseIndex: nil)) }
        case .onActiveWorkoutTap:
            sendEvent(.navigateToWorkout(restExerciseIndex: workoutRepository.activeWorkout()?.rest?.savedExerciseIndex))
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            for await (users, selectedId) in combineLatest(userRepository.observeUsers(), userRepository.observeSelectedUserId()) {
                updateState { $0.users = users.map { $0.toUserUi(isSelected: $0.id == selectedId) } }
            }
        }
        launch { [self] in
            for await status in syncManager.observeStatus() { updateState { $0.isOffline = status == .offline } }
        }
        launch { [self] in
            let trainings = userRepository.observeSelectedUserId().flatMapLatest { [trainingRepository] in
                trainingRepository.observeTrainings(userId: $0)
            }
            for await list in trainings {
                updateState {
                    $0.trainings = list.map { training in
                        TrainingCardUi(
                            id: training.id,
                            name: training.name,
                            icon: training.icon.imageName,
                            exercises: Strings.plural("training_exercise_count", training.exerciseCount),
                            sets: Strings.plural("training_set_count", training.setCount)
                        )
                    }
                    $0.isLoading = false
                }
            }
        }
        launch { [self] in
            for await workout in workoutRepository.observeActiveWorkout() {
                // A free workout gets its banner once it's started; until then Home offers "Free workout" to go back to it.
                self.workout = workout?.isClockStarted == true ? workout : nil
                showBanner(now())
            }
        }
        launch { [self] in
            for await now in ticker(now: now) { showBanner(now) }
        }
    }

    private func showBanner(_ now: Date) {
        let banner = workout.map { Self.banner($0, now: now) }
        if banner != state.activeWorkout { updateState { $0.activeWorkout = banner } }
    }

    static func banner(_ workout: Workout, now: Date) -> ActiveWorkoutUi {
        let current = workout.runningExerciseIndex.map { workout.exercises[$0] }
        let setIndex = current?.currentSetIndex
        // While a rest runs the line drains with its countdown, like the ring on the exercise screen, and stays
        // empty with "Rest over" until the next set is logged; otherwise it shows the sets.
        var restBar: (Double, String)?
        if let rest = workout.rest, rest.durationSeconds > 0 {
            if rest.isOver(now: now) {
                restBar = (0, Strings.text("workout_banner_rest_over"))
            } else {
                let remaining = rest.remaining(now: now)
                let time = Durations.clock(Int(remaining.rounded(.up)))
                restBar = (remaining / Double(rest.durationSeconds), Strings.format(rest.isPaused ? "workout_banner_rest_paused" : "workout_banner_rest", time))
            }
        }
        let subtitle = if let current, let setIndex {
            Strings.format("workout_banner_current", current.exercise.name, setIndex + 1, current.sets.count)
        } else if workout.exercises.contains(where: \.isOpen) || workout.exercises.isEmpty {
            // A free workout that has no exercise yet waits for one too.
            Strings.text("workout_banner_choose")
        } else {
            Strings.text("workout_banner_all_done")
        }
        return ActiveWorkoutUi(
            title: workout.trainingName,
            subtitle: subtitle,
            elapsed: Durations.clock(Int(workout.elapsed(now: now))),
            progress: restBar?.0 ?? (workout.setCount == 0 ? 0 : Double(workout.doneSetCount) / Double(workout.setCount)),
            progressText: restBar?.1 ?? Strings.format("workout_banner_sets", workout.doneSetCount, workout.setCount)
        )
    }
}

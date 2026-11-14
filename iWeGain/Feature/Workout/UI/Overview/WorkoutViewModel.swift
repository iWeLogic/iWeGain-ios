import Foundation

/// Overview of the active workout: progress, exercises and finishing.
final class WorkoutViewModel: BaseViewModel<WorkoutState, WorkoutAction, WorkoutEvent> {
    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date

    private var workout: Workout?
    private var hasAppeared = false

    init(
        workoutRepository: WorkoutRepository,
        exerciseRepository: ExerciseRepository,
        settingsRepository: SettingsRepository,
        now: @escaping () -> Date
    ) {
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.settingsRepository = settingsRepository
        self.now = now
        super.init(initialState: WorkoutState())
    }

    override func onAction(_ action: WorkoutAction) {
        switch action {
        case .onAppear: appear()
        case .onExerciseTap(let index): sendEvent(.navigateToExercise(index: index))
        case .onStartWorkoutTap: perform { try workoutRepository.startFreeWorkoutClock() }
        case .onFinishTap: openFinish()
        case .onFinishConfirm: finish()
        case .onFinishDismiss: updateState { $0.finish = nil }
        case .onFinishNameChange(let name): updateState { $0.finishName = name }
        case .onSaveAsTrainingChange(let enabled): updateState { $0.finish?.saveAsTraining = enabled }
        case .onAddExerciseTap: sendEvent(.navigateToExerciseLibrary)
        case .onExercisePicked(let id):
            // A picked exercise joins the list; it opens when tapped, like the others.
            guard let exercise = exerciseRepository.exercise(id: id) else { return }
            perform { try workoutRepository.addExercise(exercise) }
        case .onSwitchToFreeTap: updateState { $0.isSwitchConfirmOpen = true }
        case .onSwitchToFreeDismiss: updateState { $0.isSwitchConfirmOpen = false }
        case .onSwitchToFreeConfirm:
            updateState { $0.isSwitchConfirmOpen = false }
            perform { try workoutRepository.switchToFreeWorkout() }
        }
    }

    private func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        launch { [self] in
            for await (workout, settings) in combineLatest(workoutRepository.observeActiveWorkout(), settingsRepository.observeSettings()) {
                self.workout = workout
                if let workout { show(workout, unit: settings.weightUnit) } else { sendEvent(.close) }
            }
        }
        launch { [self] in
            for await now in ticker(now: now) {
                guard let workout else { continue }
                let elapsed = Durations.clock(Int(workout.elapsed(now: now)))
                if elapsed != state.elapsed { updateState { $0.elapsed = elapsed } }
            }
        }
    }

    private func openFinish() {
        guard let workout = workoutRepository.activeWorkout() else { return }
        updateState {
            if workout.isFree { $0.finishName = workout.trainingName }
            $0.finish = FinishSummaryUi(
                doneSets: workout.doneSetCount,
                totalSets: workout.setCount,
                unfinished: workout.exercises.enumerated()
                    .filter { $0.element.pendingCount > 0 }
                    .map { UnfinishedExerciseUi(id: $0.offset, name: $0.element.exercise.name, setsLeft: Strings.plural("finish_sets_left", $0.element.pendingCount)) },
                isFree: workout.isFree
            )
        }
    }

    /// Closing follows from the active workout becoming nil.
    private func finish() {
        let summary = state.finish
        updateState { $0.finish = nil }
        if summary?.isFree == true {
            perform { try workoutRepository.finishWorkout(name: state.finishName, saveAsTraining: summary?.saveAsTraining == true) }
        } else {
            perform { try workoutRepository.finishWorkout() }
        }
    }

    /// Runs a repository change; the data layer only throws DataError.
    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch let error as DataError {
            if let message = error.message { sendEvent(.showError(message)) }
        } catch {}
    }

    private func show(_ workout: Workout, unit: WeightUnit) {
        let pending = workout.setCount - workout.doneSetCount - workout.skippedSetCount
        let running = workout.runningExerciseIndex
        updateState {
            $0.isLoaded = true
            $0.title = workout.trainingName
            $0.icon = workout.trainingIcon.imageName
            $0.startedAt = workout.isClockStarted
                ? Strings.format("workout_started_at", workout.startedAt.formatted(date: .omitted, time: .shortened))
                : Strings.text("workout_not_started")
            // A free workout has no plan to count down: just the sets done so far.
            $0.setsProgress = workout.isFree ? "\(workout.doneSetCount)" : "\(workout.doneSetCount) / \(workout.setCount)"
            $0.setsCaption = if workout.isFree {
                Strings.text(workout.doneSetCount == 0 ? "workout_free_no_sets" : "workout_free_sets_caption")
            } else if workout.skippedSetCount > 0 {
                Strings.format("workout_sets_left_skipped", pending, workout.skippedSetCount)
            } else {
                Strings.format("workout_sets_left", pending)
            }
            $0.volume = unit.volumeText(workout.volumeKg)
            $0.exercises = workout.displayOrder.map { index in
                Self.exerciseUi(workout.exercises[index], index: index, isRunning: index == running, unit: unit)
            }
            $0.allSetsDone = workout.setsDoneAt != nil
            $0.isFree = workout.isFree
            $0.isStarted = workout.isClockStarted
            $0.elapsed = Durations.clock(Int(workout.elapsed(now: now())))
        }
    }

    static func exerciseUi(_ exercise: WorkoutExercise, index: Int, isRunning: Bool, unit: WeightUnit) -> WorkoutExerciseUi {
        let total = exercise.sets.count
        let done = exercise.doneCount
        let status: WorkoutExerciseStatus = if exercise.isSkipped && exercise.pendingCount > 0 {
            .skipped
        } else if exercise.pendingCount == 0 && done == 0 {
            .skipped
        } else if exercise.pendingCount == 0 && exercise.skippedCount > 0 {
            // Finished, but not every set was done: no ✓, the pie shows how much was.
            .partial
        } else if exercise.pendingCount == 0 {
            .done
        } else if isRunning {
            .active
        } else {
            .upcoming
        }
        let subtitle = switch status {
        case .done:
            if let best = exercise.bestSet {
                Strings.format("workout_exercise_done", done, total, unit.setResultText(best.weightKg ?? 0, reps: best.reps ?? 0))
            } else {
                Strings.format("workout_exercise_done_no_best", done, total)
            }
        case .partial:
            if let best = exercise.bestSet {
                Strings.format("workout_exercise_done_skipped", done, total, exercise.skippedCount, unit.setResultText(best.weightKg ?? 0, reps: best.reps ?? 0))
            } else {
                Strings.format("workout_exercise_done_skipped_no_best", done, total, exercise.skippedCount)
            }
        case .active: Strings.format("workout_exercise_continue", done, total)
        case .upcoming:
            if done + exercise.skippedCount > 0 {
                Strings.format("workout_exercise_partial", done, total)
            } else {
                Strings.format("workout_exercise_upcoming", Strings.plural("training_set_count", total), Durations.rest(exercise.restSeconds))
            }
        case .skipped: Strings.format("workout_exercise_skipped", done, total)
        }
        return WorkoutExerciseUi(
            index: index,
            icon: exercise.exercise.imageName,
            name: exercise.exercise.name,
            subtitle: subtitle,
            status: status,
            doneShare: total == 0 ? 1 : Double(done) / Double(total)
        )
    }
}

import Foundation

/// One exercise of the active workout: its sets, logging and editing sets (Log Set sheet), skipping
/// and the rest after a set.
final class ExerciseViewModel: BaseViewModel<ExerciseState, ExerciseAction, ExerciseEvent> {
    static let restAdjustSeconds = 15
    static let skipPillDuration: Duration = .seconds(4)

    private let exerciseIndex: Int
    /// Opens the Log Set sheet for the current set once the exercise is shown.
    private var opensLogSet: Bool
    private let workoutRepository: WorkoutRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date

    private var workout: Workout?
    private var unit = WeightUnit.kg
    private var hasAppeared = false
    private var wasRestOver = false
    private var skippedSetIndex: Int?
    private var skipPillTask: Task<Void, Never>?
    /// Removed from the free workout: its index belongs to another exercise now, so the screen stops following it.
    private var isRemoved = false
    /// Previous result of this exercise, looked up once: finishing this workout must not change the hints.
    private var history: ExerciseHistory?

    init(
        exerciseIndex: Int,
        opensLogSet: Bool = false,
        workoutRepository: WorkoutRepository,
        settingsRepository: SettingsRepository,
        now: @escaping () -> Date
    ) {
        self.exerciseIndex = exerciseIndex
        self.opensLogSet = opensLogSet
        self.workoutRepository = workoutRepository
        self.settingsRepository = settingsRepository
        self.now = now
        super.init(initialState: ExerciseState())
    }

    override func onAction(_ action: ExerciseAction) {
        switch action {
        case .onAppear: appear()
        // The rest keeps running while the Log Set sheet is open; saving the set stops it.
        case .onCompleteSetTap: openLogSet()
        case .onSkipSetTap: skipSet()
        case .onUndoSkipTap: undoSkip()
        case .onRetrySetTap(let number):
            hideSkipPill()
            perform { try workoutRepository.retrySet(exerciseIndex: exerciseIndex, setIndex: number - 1) }
        case .onStartExerciseTap:
            perform {
                // A rest left from another exercise ends when the next one starts.
                if workoutRepository.activeWorkout()?.rest != nil { try workoutRepository.endRest() }
                try workoutRepository.startExercise(exerciseIndex: exerciseIndex)
            }
        case .onChangeExerciseTap: updateState { $0.isChangeDialogOpen = $0.blockingExercise != nil }
        case .onGoToRunningTap:
            updateState { $0.isChangeDialogOpen = false }
            if let blocking = state.blockingExercise { sendEvent(.navigateToExercise(index: blocking.index)) }
        case .onChangeExerciseConfirm:
            updateState { $0.isChangeDialogOpen = false }
            perform { try workoutRepository.changeExercise(exerciseIndex: exerciseIndex) }
        case .onChangeExerciseDismiss: updateState { $0.isChangeDialogOpen = false }
        case .onContinueTap:
            if state.rest.isActive && state.rest.isOver { perform { try workoutRepository.endRest() } }
            sendEvent(.backToWorkout)
        case .onEditSetTap(let number): openEditSet(setIndex: number - 1)
        case .onAddSetTap: perform { try workoutRepository.addSet(exerciseIndex: exerciseIndex) }
        case .onRemoveExerciseTap: updateState { $0.isRemoveConfirmOpen = true }
        case .onRemoveExerciseDismiss: updateState { $0.isRemoveConfirmOpen = false }
        case .onRemoveExerciseConfirm:
            isRemoved = true
            updateState { $0.isRemoveConfirmOpen = false }
            sendEvent(.backToWorkout)
            perform { try workoutRepository.removeExercise(exerciseIndex: exerciseIndex) }
        case .onRestMinusTap: perform { try workoutRepository.adjustRest(deltaSeconds: -Self.restAdjustSeconds) }
        case .onRestPlusTap: perform { try workoutRepository.adjustRest(deltaSeconds: Self.restAdjustSeconds) }
        case .onRestPauseTap:
            perform { if state.rest.isPaused { try workoutRepository.resumeRest() } else { try workoutRepository.pauseRest() } }
        case .onRestCancelTap: perform { try workoutRepository.endRest() }
        case .onLogSet(let logSetAction):
            switch logSetAction {
            case .onSave: saveSet()
            case .onDelete: deleteSet()
            case .onDismiss: updateState { $0.logSet = nil }
            default: updateState { $0.logSet = $0.logSet?.reduce(logSetAction, weightStep: unit.step) }
            }
        }
    }

    private func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        if let active = workoutRepository.activeWorkout(), active.exercises.indices.contains(exerciseIndex) {
            history = workoutRepository.lastHistory(userId: active.userId, exerciseId: active.exercises[exerciseIndex].exercise.id)
        }
        launch { [self] in
            for await (workout, settings) in combineLatest(workoutRepository.observeActiveWorkout(), settingsRepository.observeSettings()) {
                guard !isRemoved else { continue }
                self.workout = workout
                unit = settings.weightUnit
                if let workout, workout.exercises.indices.contains(exerciseIndex) {
                    show(workout)
                    tick(now())
                    if opensLogSet {
                        opensLogSet = false
                        openLogSet()
                    }
                } else {
                    sendEvent(.backToWorkout)
                }
            }
        }
        // The workout clock and this exercise's rest, smooth enough for the countdown.
        launch { [self] in
            for await now in ticker(every: .milliseconds(250), now: now) { tick(now) }
        }
    }

    private func tick(_ now: Date) {
        guard let workout, !isRemoved, workout.exercises.indices.contains(exerciseIndex) else { return }
        let elapsed = Durations.clock(Int(workout.elapsed(now: now)))
        let rest = restUi(workout, now: now)
        let isOver = rest.isActive && rest.isOver
        if isOver && !wasRestOver { sendEvent(.restOver) }
        wasRestOver = isOver
        if elapsed != state.elapsed || rest != state.rest {
            updateState {
                $0.elapsed = elapsed
                $0.rest = rest
            }
        }
    }

    /// This exercise's rest; 0:00 with the exercise's rest time when there is none.
    private func restUi(_ workout: Workout, now: Date) -> RestUi {
        guard let rest = workout.rest, rest.savedExerciseIndex == exerciseIndex else {
            let seconds = workout.exercises[exerciseIndex].restSeconds
            return RestUi(durationSeconds: seconds, total: Durations.clock(seconds))
        }
        let remainingSeconds = Int(rest.remaining(now: now).rounded(.up))
        return RestUi(
            isActive: true,
            endsAt: rest.endsAt,
            durationSeconds: rest.durationSeconds,
            pausedRemaining: rest.isPaused ? rest.remaining(now: now) : nil,
            remaining: Durations.clock(remainingSeconds),
            total: Durations.clock(rest.durationSeconds),
            isOver: remainingSeconds == 0
        )
    }

    private func show(_ workout: Workout) {
        let exercise = workout.exercises[exerciseIndex]
        let current = exercise.currentSetIndex
        let phase: ExercisePhase = if exercise.isRunning {
            .running
        } else if exercise.isSkipped && exercise.pendingCount > 0 {
            .skipped
        } else if current == nil {
            .done
        } else {
            .ready
        }
        let running = workout.runningExerciseIndex
        let otherRunning = running.map { $0 != exerciseIndex } ?? false
        updateState {
            $0.isLoaded = true
            $0.name = exercise.exercise.name
            $0.subtitle = Strings.format(
                "exercise_header_subtitle",
                String(localized: exercise.exercise.muscleGroup.label),
                String(localized: exercise.exercise.equipment.label),
                (workout.displayOrder.firstIndex(of: exerciseIndex) ?? exerciseIndex) + 1,
                workout.exercises.count
            )
            $0.sets = exercise.sets.enumerated().map { index, set in
                let status: WorkoutSetStatus = switch set.status {
                case .done: .done
                case .skipped: .skipped
                case .pending: index == current && phase == .running ? .current : .upcoming
                }
                return SetRowUi(
                    number: index + 1,
                    weight: unit.weightText(set.weightKg ?? set.targetWeightKg),
                    reps: Strings.format("exercise_reps", set.reps ?? set.targetReps),
                    status: status,
                    canRetry: status == .skipped && !otherRunning,
                    canEdit: status == .done
                )
            }
            $0.restInfo = exercise.restSeconds > 0 ? Strings.format("exercise_rest_info", Durations.rest(exercise.restSeconds)) : nil
            $0.phase = phase
            $0.blockingExercise = running.flatMap { index in
                index == exerciseIndex ? nil : BlockingExerciseUi(index: index, name: workout.exercises[index].exercise.name)
            }
            // Closes by itself once nothing blocks this exercise any more.
            $0.isChangeDialogOpen = $0.isChangeDialogOpen && otherRunning
            $0.canAddSet = workout.isFree && !otherRunning
            $0.canRemoveExercise = workout.isFree
            $0.isWorkoutStarted = workout.isClockStarted
        }
    }

    // MARK: Log Set

    private func openLogSet() {
        guard let workout = workoutRepository.activeWorkout(), workout.exercises.indices.contains(exerciseIndex) else { return }
        let exercise = workout.exercises[exerciseIndex]
        guard exercise.isRunning, let setIndex = exercise.currentSetIndex else { return }
        let set = exercise.sets[setIndex]
        hideSkipPill()
        updateState {
            $0.logSet = logSetUi(
                exercise: exercise,
                setIndex: setIndex,
                weightKg: set.targetWeightKg,
                reps: set.targetReps,
                startsRest: workout.restFollows(exerciseIndex: exerciseIndex, setIndex: setIndex),
                isEdit: false,
                canDelete: workout.isFree
            )
        }
    }

    /// Log Set for a done set, prefilled with what was logged; saving changes it without starting a rest.
    private func openEditSet(setIndex: Int) {
        guard let workout = workoutRepository.activeWorkout(), workout.exercises.indices.contains(exerciseIndex) else { return }
        let exercise = workout.exercises[exerciseIndex]
        guard exercise.sets.indices.contains(setIndex), exercise.sets[setIndex].status == .done else { return }
        let set = exercise.sets[setIndex]
        hideSkipPill()
        updateState {
            $0.logSet = logSetUi(
                exercise: exercise,
                setIndex: setIndex,
                weightKg: set.weightKg ?? set.targetWeightKg,
                reps: set.reps ?? set.targetReps,
                startsRest: false,
                isEdit: true,
                canDelete: workout.isFree
            )
        }
    }

    private func logSetUi(exercise: WorkoutExercise, setIndex: Int, weightKg: Double, reps: Int, startsRest: Bool, isEdit: Bool, canDelete: Bool) -> LogSetUi {
        let last = history.flatMap { $0.sets.indices.contains(setIndex) ? $0.sets[setIndex] : nil }
        return LogSetUi(
            setNumber: setIndex + 1,
            exerciseName: exercise.exercise.name,
            weightLabel: Strings.text(unit == .kg ? "log_set_weight_kg" : "log_set_weight_lb"),
            weight: unit.weightNumber(weightKg),
            reps: String(reps),
            weightHint: last?.weightKg.map { Strings.format("log_set_last_time", unit.weightText($0)) },
            repsHint: last?.reps.map { Strings.format("log_set_last_time", String($0)) },
            startsRest: startsRest,
            isEdit: isEdit,
            canDelete: canDelete
        )
    }

    private func saveSet() {
        guard let logSet = state.logSet, logSet.canSave, let reps = Int(logSet.reps) else { return }
        let weightKg = unit.toKg(Double(logSet.weight) ?? 0)
        updateState { $0.logSet = nil }
        if logSet.isEdit {
            perform { try workoutRepository.editSet(exerciseIndex: exerciseIndex, setIndex: logSet.setNumber - 1, weightKg: weightKg, reps: reps) }
            return
        }
        guard let setIndex = workoutRepository.activeWorkout()?.exercises[safe: exerciseIndex]?.currentSetIndex else { return }
        // Saving the set stops the rest (it may have kept running while the sheet was open) and starts the next one.
        do {
            try workoutRepository.logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weightKg: weightKg, reps: reps)
        } catch {
            showError(error)
            return
        }
        // The last set of this exercise: pick the next exercise on the overview. A free workout stays,
        // since sets are added there one by one.
        if let updated = workoutRepository.activeWorkout(), !updated.isFree, updated.exercises[safe: exerciseIndex]?.isOpen == false {
            sendEvent(.backToWorkout)
        }
    }

    /// Free workouts: "Delete set" in the Log Set sheet. Deleting the only set removes the exercise
    /// too, and the screen goes back to the list of exercises.
    private func deleteSet() {
        guard let logSet = state.logSet else { return }
        let isLastSet = state.sets.count == 1
        updateState { $0.logSet = nil }
        if isLastSet {
            isRemoved = true
            sendEvent(.backToWorkout)
        }
        perform { try workoutRepository.deleteSet(exerciseIndex: exerciseIndex, setIndex: logSet.setNumber - 1) }
    }

    // MARK: Skipping

    private func skipSet() {
        guard let exercise = workoutRepository.activeWorkout()?.exercises[safe: exerciseIndex], exercise.isRunning,
              let setIndex = exercise.currentSetIndex else { return }
        do {
            try workoutRepository.skipSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
        } catch {
            showError(error)
            return
        }
        skippedSetIndex = setIndex
        updateState { $0.skippedSetNumber = setIndex + 1 }
        skipPillTask?.cancel()
        skipPillTask = Task { [weak self] in
            try? await Task.sleep(for: Self.skipPillDuration)
            guard !Task.isCancelled else { return }
            self?.hideSkipPill()
        }
    }

    private func undoSkip() {
        guard let setIndex = skippedSetIndex else { return }
        hideSkipPill()
        perform { try workoutRepository.undoSkipSet(exerciseIndex: exerciseIndex, setIndex: setIndex) }
    }

    private func hideSkipPill() {
        skipPillTask?.cancel()
        skippedSetIndex = nil
        if state.skippedSetNumber != nil { updateState { $0.skippedSetNumber = nil } }
    }

    private func perform(_ change: () throws -> Void) {
        do { try change() } catch let error as DataError { showError(error) } catch {}
    }

    private func showError(_ error: DataError) {
        if let message = error.message { sendEvent(.showError(message)) }
    }
}

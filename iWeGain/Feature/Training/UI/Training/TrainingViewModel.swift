import Foundation

/// Shows an existing training read-only, edits it, or creates a new one ([trainingId] nil).
final class TrainingViewModel: BaseViewModel<TrainingState, TrainingAction, TrainingEvent> {
    static let defaultSets = 3
    static let minSets = 1
    static let maxSets = 20
    static let minRestSeconds = 0
    static let maxRestSeconds = 600
    static let restStepSeconds = 15

    private struct Draft: Equatable {
        let key: String
        var exercise: Exercise
        var sets: Int
        var restSeconds: Int
    }

    private let trainingId: String?
    private let trainingRepository: TrainingRepository
    private let exerciseRepository: ExerciseRepository
    private let userRepository: UserRepository
    private let settingsRepository: SettingsRepository
    private let workoutRepository: WorkoutRepository

    /// The saved training being viewed or edited; nil while creating a new one (or until it's loaded).
    private var saved: Training?
    private var drafts: [Draft] = []
    /// Save was pressed with something missing: from then on, empty required parts are marked.
    private var showMissing = false
    private var hasAppeared = false

    init(
        trainingId: String?,
        trainingRepository: TrainingRepository,
        exerciseRepository: ExerciseRepository,
        userRepository: UserRepository,
        settingsRepository: SettingsRepository,
        workoutRepository: WorkoutRepository
    ) {
        self.trainingId = trainingId
        self.trainingRepository = trainingRepository
        self.exerciseRepository = exerciseRepository
        self.userRepository = userRepository
        self.settingsRepository = settingsRepository
        self.workoutRepository = workoutRepository
        super.init(initialState: TrainingState(isNew: trainingId == nil, isEditing: trainingId == nil))
    }

    override func onAction(_ action: TrainingAction) {
        switch action {
        case .onAppear: appear()
        case .onNameChange(let name):
            updateState { $0.name = name }
            updateMissing()
        case .onIconTap: updateState { $0.isIconPickerOpen = true }
        case .onIconSelect(let icon):
            updateState {
                $0.icon = icon
                $0.isIconPickerOpen = false
            }
            updateMissing()
        case .onIconPickerDismiss: updateState { $0.isIconPickerOpen = false }
        case .onAddExerciseTap: sendEvent(.navigateToExerciseLibrary)
        case .onExercisePicked(let id): addExercise(id: id)
        case .onSetsDecrease(let key): updateDraft(key) { $0.sets = max(Self.minSets, $0.sets - 1) }
        case .onSetsIncrease(let key): updateDraft(key) { $0.sets = min(Self.maxSets, $0.sets + 1) }
        case .onRestDecrease(let key): updateDraft(key) { $0.restSeconds = max(Self.minRestSeconds, $0.restSeconds - Self.restStepSeconds) }
        case .onRestIncrease(let key): updateDraft(key) { $0.restSeconds = min(Self.maxRestSeconds, $0.restSeconds + Self.restStepSeconds) }
        case .onRemoveExercise(let key): setDrafts(drafts.filter { $0.key != key })
        case .onMoveExercises(let from, let to):
            // List's move: [to] counts positions before the moved rows are taken out.
            let moving = from.map { drafts[$0] }
            var rest = drafts.enumerated().filter { !from.contains($0.offset) }.map(\.element)
            rest.insert(contentsOf: moving, at: to - from.count { $0 < to })
            setDrafts(rest)
        case .onSaveTap: save()
        case .onCancelTap:
            if let saved { showSaved(saved) } else { sendEvent(.close) }
        case .onEditTap: updateState { $0.isEditing = true }
        // The stored name: the field may hold unsaved edits.
        case .onDeleteTap: if let saved { updateState { $0.deleteConfirmName = saved.name } }
        case .onDeleteDismiss: updateState { $0.deleteConfirmName = nil }
        case .onDeleteConfirm: delete()
        case .onStartTap: startWorkout()
        case .onGoToActiveWorkoutTap:
            if let workout = workoutRepository.activeWorkout() {
                sendEvent(.navigateToWorkout(restExerciseIndex: workout.rest?.savedExerciseIndex))
            }
        }
    }

    private func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        load()
        launch { [self] in
            for await active in workoutRepository.observeActiveWorkout() {
                // An unstarted free workout doesn't stand in the way: starting the training replaces it.
                let workout = active?.isClockStarted == true ? active : nil
                updateState {
                    $0.isWorkoutActive = workout != nil && workout?.trainingId == trainingId
                    $0.otherActiveWorkout = workout.flatMap { $0.trainingId == trainingId ? nil : $0.trainingName }
                }
            }
        }
        // Keep drafts in sync when a custom exercise is edited in the library.
        launch { [self] in
            for await exercises in exerciseRepository.observeAllExercises() {
                let byId = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let updated = drafts.map { draft in
                    var copy = draft
                    if let exercise = byId[draft.exercise.id] { copy.exercise = exercise }
                    return copy
                }
                if updated != drafts {
                    drafts = updated
                    publishDrafts()
                }
            }
        }
    }

    private func startWorkout() {
        guard let trainingId else { return }
        // Read it again so edits to custom exercises are included.
        guard let training = try? trainingRepository.training(id: trainingId), !training.exercises.isEmpty else { return }
        do {
            let workout = try workoutRepository.startWorkout(training)
            sendEvent(.navigateToWorkout(restExerciseIndex: workout.rest?.savedExerciseIndex))
        } catch {
            // Another training's workout is in progress: the screen offers to go to it instead.
            if error == .storage { sendEvent(.showError("error_unknown")) }
        }
    }

    private func load() {
        if let trainingId {
            do {
                guard let training = try trainingRepository.training(id: trainingId) else {
                    sendEvent(.close)
                    return
                }
                saved = training
                showSaved(training)
            } catch {
                showError(error)
                sendEvent(.close)
                return
            }
        }
        updateState { $0.isLoaded = true }
    }

    /// Read-only mode with the stored values; drops any unsaved edits.
    private func showSaved(_ training: Training) {
        drafts = training.exercises.map { Draft(key: UUID().uuidString, exercise: $0.exercise, sets: $0.sets, restSeconds: $0.restSeconds) }
        updateState {
            $0.isEditing = false
            $0.name = training.name
            $0.icon = training.icon
        }
        publishDrafts()
    }

    private func addExercise(id: String) {
        guard let exercise = exerciseRepository.exercise(id: id) else { return }
        let rest = settingsRepository.settings.defaultRestSeconds
        setDrafts(drafts + [Draft(key: UUID().uuidString, exercise: exercise, sets: Self.defaultSets, restSeconds: rest)])
    }

    private func updateDraft(_ key: String, _ change: (inout Draft) -> Void) {
        setDrafts(drafts.map { draft in
            guard draft.key == key else { return draft }
            var copy = draft
            change(&copy)
            return copy
        })
    }

    private func save() {
        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let icon = state.icon, !name.isEmpty, !drafts.isEmpty else {
            showMissing = true
            updateMissing()
            return
        }
        let training = Training(
            id: saved?.id ?? UUID().uuidString.lowercased(),
            userId: saved?.userId ?? userRepository.selectedUserId,
            name: name,
            icon: icon,
            exercises: drafts.map { TrainingExercise(exercise: $0.exercise, sets: $0.sets, restSeconds: $0.restSeconds) }
        )
        do {
            try trainingRepository.saveTraining(training)
        } catch {
            showError(error)
            return
        }
        if saved == nil {
            sendEvent(.close)
        } else {
            saved = training
            showSaved(training)
        }
    }

    private func delete() {
        guard let id = saved?.id, !state.isDeleting else { return }
        updateState { $0.isDeleting = true }
        do {
            try trainingRepository.deleteTraining(id: id)
            sendEvent(.close)
        } catch {
            updateState {
                $0.isDeleting = false
                $0.deleteConfirmName = nil
            }
            showError(error)
        }
    }

    private func setDrafts(_ newDrafts: [Draft]) {
        drafts = newDrafts
        publishDrafts()
    }

    private func publishDrafts() {
        updateState { $0.exercises = drafts.map(Self.toUi) }
        updateMissing()
    }

    private func updateMissing() {
        updateState {
            $0.isIconMissing = showMissing && $0.icon == nil
            $0.isNameMissing = showMissing && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            $0.isExercisesMissing = showMissing && $0.exercises.isEmpty
        }
    }

    private func showError(_ error: DataError) {
        if let message = error.message { sendEvent(.showError(message)) }
    }

    private static func toUi(_ draft: Draft) -> ExerciseDraftUi {
        ExerciseDraftUi(
            id: draft.key,
            icon: draft.exercise.imageName,
            name: draft.exercise.name,
            subtitle: Strings.format("exercise_subtitle", String(localized: draft.exercise.muscleGroup.label), String(localized: draft.exercise.equipment.label)),
            sets: "\(draft.sets)",
            rest: Durations.rest(draft.restSeconds),
            canDecreaseSets: draft.sets > minSets,
            canIncreaseSets: draft.sets < maxSets,
            canDecreaseRest: draft.restSeconds > minRestSeconds,
            canIncreaseRest: draft.restSeconds < maxRestSeconds
        )
    }
}

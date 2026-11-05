import Foundation

/// Changes the results of a finished workout (Figma "06b · Edit Workout"): the weight, reps and status
/// of each set; in a free workout also adding or deleting sets and exercises (a training's workout
/// keeps its exercises and sets). Everything happens on a draft; Save writes it in one go and Cancel drops it.
final class EditWorkoutViewModel: BaseViewModel<EditWorkoutState, EditWorkoutAction, EditWorkoutEvent> {
    static let defaultWeightKg = 20.0
    static let defaultReps = 10

    private struct DraftExercise: Equatable {
        let key: String
        var exercise: WorkoutExercise
    }

    /// The set the sheet edits; [setIndex] is nil for a new set.
    private struct SetTarget {
        let exerciseKey: String
        let setIndex: Int?
    }

    private let workoutId: String
    private let workoutRepository: WorkoutRepository
    private let exerciseRepository: ExerciseRepository
    private let settingsRepository: SettingsRepository
    private var isStarted = false
    private var unit: WeightUnit = .kg
    private var userId = ""
    private var original: [WorkoutExercise] = []
    private var draft: [DraftExercise] = []
    private var editing: SetTarget?
    private var isFree = false

    init(workoutId: String, workoutRepository: WorkoutRepository, exerciseRepository: ExerciseRepository, settingsRepository: SettingsRepository) {
        self.workoutId = workoutId
        self.workoutRepository = workoutRepository
        self.exerciseRepository = exerciseRepository
        self.settingsRepository = settingsRepository
        super.init(initialState: EditWorkoutState())
    }

    override func onAction(_ action: EditWorkoutAction) {
        switch action {
        case .onAppear: start()
        case .onCancelTap:
            if hasChanges { updateState { $0.isDiscardConfirmOpen = true } } else { sendEvent(.close) }
        case .onSaveTap: save()
        case .onDiscardConfirm:
            updateState { $0.isDiscardConfirmOpen = false }
            sendEvent(.close)
        case .onDiscardDismiss: updateState { $0.isDiscardConfirmOpen = false }
        case .onSetTap(let key, let setIndex): openSet(SetTarget(exerciseKey: key, setIndex: setIndex))
        case .onAddSetTap(let key): if isFree { openSet(SetTarget(exerciseKey: key, setIndex: nil)) }
        case .onLogSet(let logSetAction):
            switch logSetAction {
            case .onSave: saveSet()
            case .onDelete: deleteSet()
            case .onDismiss: closeSet()
            default: updateState { $0.logSet = $0.logSet?.reduce(logSetAction, weightStep: unit.step) }
            }
        case .onDeleteExerciseTap(let key):
            guard isFree, let entry = draft.first(where: { $0.key == key }) else { return }
            updateState { $0.deleteExercise = DeleteExerciseUi(key: entry.key, name: entry.exercise.exercise.name, setCount: entry.exercise.sets.count) }
        case .onDeleteExerciseConfirm:
            guard let key = state.deleteExercise?.key else { return }
            draft.removeAll { $0.key == key }
            updateState { $0.deleteExercise = nil }
            show()
        case .onDeleteExerciseDismiss: updateState { $0.deleteExercise = nil }
        case .onAddExerciseTap: if isFree { sendEvent(.navigateToExerciseLibrary) }
        case .onExercisePicked(let id): if isFree { addExercise(id) }
        case .onDeleteWorkoutTap: updateState { $0.isDeleteConfirmOpen = true }
        case .onDeleteWorkoutDismiss: updateState { $0.isDeleteConfirmOpen = false }
        case .onDeleteWorkoutConfirm: deleteWorkout()
        }
    }

    private func start() {
        guard !isStarted else { return }
        isStarted = true
        guard let workout = try? workoutRepository.storedWorkout(id: workoutId), workout.finishedAt != nil else {
            sendEvent(.close)
            return
        }
        userId = workout.userId
        isFree = workout.isFree
        original = workout.exercises
        draft = workout.exercises.map { DraftExercise(key: UUID().uuidString, exercise: $0) }
        unit = settingsRepository.settings.weightUnit
        updateState { state in
            state.isLoaded = true
            state.title = workout.trainingName
            state.isFree = workout.isFree
        }
        show()
        launch { [self] in
            for await settings in settingsRepository.observeSettings() where settings.weightUnit != unit {
                unit = settings.weightUnit
                show()
            }
        }
    }

    private var hasChanges: Bool { draft.map(\.exercise) != original }

    private func show() {
        let exercises = draft.map(\.exercise)
        var muscles: [MuscleGroup] = []
        for muscle in exercises.map(\.exercise.muscleGroup) where !muscles.contains(muscle) { muscles.append(muscle) }
        updateState { state in
            state.muscles = muscles.map { String(localized: $0.label) }
            state.exercises = draft.map(exerciseUi)
            state.canSave = exercises.contains { !$0.sets.isEmpty }
        }
    }

    private func exerciseUi(_ entry: DraftExercise) -> EditExerciseUi {
        let exercise = entry.exercise.exercise
        return EditExerciseUi(
            key: entry.key,
            // Stored workouts don't keep a built-in exercise's picture; the library has it.
            icon: exerciseRepository.exercise(id: exercise.id)?.imageName ?? exercise.imageName,
            name: exercise.name,
            subtitle: Strings.format("exercise_subtitle", String(localized: exercise.muscleGroup.label), String(localized: exercise.equipment.label)),
            sets: entry.exercise.sets.enumerated().map { index, set in
                let isDone = set.status == .done
                return ExerciseResultSet(
                    number: index + 1,
                    weight: isDone ? unit.weightText(set.weightKg ?? 0) : Strings.text("workout_details_set_skipped"),
                    reps: isDone ? Strings.format("workout_details_reps", set.reps ?? 0) : "—",
                    isDone: isDone
                )
            }
        )
    }

    /// Opens the sheet for a set, or for a new one prefilled from the exercise's last set (or last time's result).
    private func openSet(_ target: SetTarget) {
        guard let exercise = draft.first(where: { $0.key == target.exerciseKey })?.exercise else { return }
        let set: WorkoutSet?
        if let setIndex = target.setIndex {
            guard exercise.sets.indices.contains(setIndex) else { return }
            set = exercise.sets[setIndex]
        } else {
            set = nil
        }
        let weightKg: Double
        let reps: Int
        if let set {
            weightKg = set.weightKg ?? set.targetWeightKg
            reps = set.reps ?? set.targetReps
        } else {
            let previous = exercise.sets.last ?? workoutRepository.lastHistory(userId: userId, exerciseId: exercise.exercise.id)?.sets.last
            weightKg = previous.map { $0.weightKg ?? $0.targetWeightKg } ?? Self.defaultWeightKg
            reps = previous.map { $0.reps ?? $0.targetReps } ?? Self.defaultReps
        }
        editing = target
        updateState { state in
            state.logSet = LogSetUi(
                setNumber: (target.setIndex ?? exercise.sets.count) + 1,
                exerciseName: exercise.exercise.name,
                weightLabel: Strings.text(unit == .kg ? "log_set_weight_kg" : "log_set_weight_lb"),
                weight: unit.weightNumber(weightKg),
                reps: String(reps),
                isEdit: true,
                isDone: set == nil || set?.status == .done,
                canDelete: set != nil && isFree
            )
        }
    }

    private func saveSet() {
        guard let logSet = state.logSet, let target = editing, logSet.canSave else { return }
        let weightKg = unit.toKg(Double(logSet.weight) ?? 0)
        let reps = max(1, Int(logSet.reps) ?? 0)
        let isDone = logSet.isDone != false
        updateExercise(target.exerciseKey) { exercise in
            var updated = target.setIndex.flatMap { exercise.sets.indices.contains($0) ? exercise.sets[$0] : nil }
                ?? WorkoutSet(status: .done, targetWeightKg: weightKg, targetReps: reps)
            if isDone {
                updated.status = .done
                updated.weightKg = weightKg
                updated.reps = reps
            } else {
                updated.status = .skipped
                updated.weightKg = nil
                updated.reps = nil
                updated.targetWeightKg = weightKg
                updated.targetReps = reps
            }
            if let setIndex = target.setIndex { exercise.sets[setIndex] = updated } else { exercise.sets.append(updated) }
        }
        closeSet()
    }

    private func deleteSet() {
        guard isFree, let target = editing, let setIndex = target.setIndex else { return }
        updateExercise(target.exerciseKey) { $0.sets.remove(at: setIndex) }
        // Without sets the exercise has nothing left to show.
        draft.removeAll { $0.key == target.exerciseKey && $0.exercise.sets.isEmpty }
        show()
        closeSet()
    }

    private func closeSet() {
        editing = nil
        updateState { $0.logSet = nil }
    }

    /// A picked exercise starts without sets; the sheet for its first set opens right away.
    private func addExercise(_ exerciseId: String) {
        guard let exercise = exerciseRepository.exercise(id: exerciseId) else { return }
        let entry = DraftExercise(key: UUID().uuidString, exercise: WorkoutExercise(exercise: exercise, restSeconds: 0, sets: []))
        draft.append(entry)
        show()
        openSet(SetTarget(exerciseKey: entry.key, setIndex: nil))
    }

    private func updateExercise(_ key: String, _ update: (inout WorkoutExercise) -> Void) {
        guard let index = draft.firstIndex(where: { $0.key == key }) else { return }
        update(&draft[index].exercise)
        show()
    }

    /// Exercises left without sets are dropped: a finished workout only keeps what was done or skipped.
    private func save() {
        guard state.canSave else { return }
        guard hasChanges else {
            sendEvent(.close)
            return
        }
        do throws(DataError) {
            try workoutRepository.updateFinishedWorkout(id: workoutId, exercises: draft.map(\.exercise).filter { !$0.sets.isEmpty })
            sendEvent(.close)
        } catch {
            showError(error)
        }
    }

    private func deleteWorkout() {
        updateState { $0.isDeleteConfirmOpen = false }
        do throws(DataError) {
            try workoutRepository.deleteWorkout(id: workoutId)
            sendEvent(.close)
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: DataError) {
        if let message = error.message { sendEvent(.showError(message)) }
    }
}

import Foundation

/// The selected person's exercise library, filtered by search and muscle group. Tapping an exercise picks it
/// for the training; custom exercises can be created (and are picked right away) or edited.
final class ExerciseLibraryViewModel: BaseViewModel<ExerciseLibraryState, ExerciseLibraryAction, ExerciseLibraryEvent> {
    private let exerciseRepository: ExerciseRepository
    private let userRepository: UserRepository
    private var exercises: [Exercise] = []
    private var hasAppeared = false

    init(exerciseRepository: ExerciseRepository, userRepository: UserRepository) {
        self.exerciseRepository = exerciseRepository
        self.userRepository = userRepository
        super.init(initialState: ExerciseLibraryState())
    }

    override func onAction(_ action: ExerciseLibraryAction) {
        switch action {
        case .onAppear: observeExercises()
        case .onQueryChange(let query):
            updateState { $0.query = query }
            publishSections()
        case .onMuscleGroupTap(let group):
            updateState { $0.selectedMuscleGroup = group }
            publishSections()
        case .onExerciseTap(let id): sendEvent(.exercisePicked(id: id))
        case .onCreateCustomTap: updateState { $0.form = ExerciseFormState() }
        case .onEditCustomTap(let id):
            guard let exercise = exerciseRepository.exercise(id: id), exercise.isCustom else { return }
            updateState {
                $0.form = ExerciseFormState(
                    editingExerciseId: exercise.id, name: exercise.name, icon: exercise.icon,
                    muscleGroup: exercise.muscleGroup, equipment: exercise.equipment
                )
            }
        case .onFormDismiss: updateState { $0.form = nil }
        case .onFormNameChange(let name): updateForm { $0.name = name }
        case .onFormIconTap: updateForm { $0.isIconPickerOpen = true }
        case .onFormIconSelect(let icon): updateForm {
            $0.icon = icon
            $0.isIconPickerOpen = false
        }
        case .onFormIconDismiss: updateForm { $0.isIconPickerOpen = false }
        case .onFormMuscleGroupTap(let group): updateForm { $0.muscleGroup = group }
        case .onFormEquipmentTap(let equipment): updateForm { $0.equipment = equipment }
        case .onFormSubmit: submitForm()
        }
    }

    private func observeExercises() {
        guard !hasAppeared else { return }
        hasAppeared = true
        launch { [self] in
            // The selected person's library: the built-in exercises plus their own custom ones.
            let library = userRepository.observeSelectedUserId().flatMapLatest { [exerciseRepository] in
                exerciseRepository.observeExercises(userId: $0)
            }
            for await exercises in library {
                self.exercises = exercises
                publishSections()
                updateState { $0.isLoading = false }
            }
        }
    }

    private func publishSections() {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = state.selectedMuscleGroup
        let filtered = exercises.filter { exercise in
            (group == nil || exercise.muscleGroup == group) && (query.isEmpty || exercise.name.localizedCaseInsensitiveContains(query))
        }
        let sections = MuscleGroup.allCases.compactMap { muscleGroup -> ExerciseSectionUi? in
            let rows = filtered.filter { $0.muscleGroup == muscleGroup }.map { exercise in
                ExerciseRowUi(
                    id: exercise.id,
                    icon: exercise.imageName,
                    name: exercise.name,
                    subtitle: Strings.format("exercise_subtitle", String(localized: exercise.muscleGroup.label), String(localized: exercise.equipment.label)),
                    isCustom: exercise.isCustom
                )
            }
            return rows.isEmpty ? nil : ExerciseSectionUi(muscleGroup: muscleGroup, exercises: rows)
        }
        updateState { $0.sections = sections }
    }

    /// Creating saves the exercise and picks it for the training, like tapping a library row.
    /// Editing saves the changes and stays in the library.
    private func submitForm() {
        guard let form = state.form else { return }
        let name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let icon = form.icon, let muscleGroup = form.muscleGroup, let equipment = form.equipment, !name.isEmpty else {
            updateForm { $0.showMissing = true }
            return
        }
        do {
            if let editingId = form.editingExerciseId {
                guard var existing = exerciseRepository.exercise(id: editingId) else { return }
                existing.name = name
                existing.icon = icon
                existing.muscleGroup = muscleGroup
                existing.equipment = equipment
                try exerciseRepository.updateExercise(existing)
                updateState { $0.form = nil }
            } else {
                let exercise = try exerciseRepository.createExercise(
                    userId: userRepository.selectedUserId, name: name, muscleGroup: muscleGroup, equipment: equipment, icon: icon
                )
                updateState { $0.form = nil }
                sendEvent(.exercisePicked(id: exercise.id))
            }
        } catch {
            if let message = error.message { sendEvent(.showError(message)) }
        }
    }

    /// Changes the open form; does nothing while the sheet is closed.
    private func updateForm(_ change: (inout ExerciseFormState) -> Void) {
        updateState { state in
            guard var form = state.form else { return }
            change(&form)
            state.form = form
        }
    }
}

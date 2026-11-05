import Foundation

struct TrainingState: Equatable {
    /// true when creating a training; false for an existing one opened from Home.
    var isNew = true
    /// Existing trainings open read-only; Edit switches to the editor. New ones are always edited.
    var isEditing = true
    /// The stored training is shown; until then the content stays hidden so nothing jumps.
    var isLoaded = false
    var name = ""
    /// nil until the user picks one; the editor then shows an empty icon tile.
    var icon: ItemIcon?
    var exercises: [ExerciseDraftUi] = []
    var isIconPickerOpen = false
    /// Save was pressed with these left empty: each gets a red border until it's filled.
    var isIconMissing = false
    var isNameMissing = false
    var isExercisesMissing = false
    /// A workout of this training is in progress: the start button continues it.
    var isWorkoutActive = false
    /// Name of another training whose workout is in progress; this one can't start until it's finished.
    var otherActiveWorkout: String?
    /// Name shown in the "Delete …?" confirmation; nil while it's closed.
    var deleteConfirmName: String?
    var isDeleting = false

    /// "Exercises" or "Exercises · 3".
    var exercisesLabel: String {
        exercises.isEmpty ? Strings.text("training_exercises") : Strings.format("training_exercises_count", exercises.count)
    }

    /// "Hold ⠿ to reorder", while editing more than one exercise.
    var reorderHint: String? {
        isEditing && exercises.count > 1 ? Strings.text("training_reorder_hint") : nil
    }
}

/// One exercise in the editor. [id] is unique per entry, so the same exercise can be added twice.
struct ExerciseDraftUi: Identifiable, Equatable {
    let id: String
    let icon: String
    let name: String
    /// "Chest · Barbell".
    let subtitle: String
    let sets: String
    let rest: String
    let canDecreaseSets: Bool
    let canIncreaseSets: Bool
    let canDecreaseRest: Bool
    let canIncreaseRest: Bool
}

enum TrainingAction {
    case onAppear
    case onNameChange(String)
    case onIconTap
    case onIconSelect(ItemIcon)
    case onIconPickerDismiss
    case onAddExerciseTap
    case onExercisePicked(id: String)
    case onSetsDecrease(id: String)
    case onSetsIncrease(id: String)
    case onRestDecrease(id: String)
    case onRestIncrease(id: String)
    case onRemoveExercise(id: String)
    case onMoveExercises(from: IndexSet, to: Int)
    case onSaveTap
    /// New training: close. Existing training: discard edits and return to view mode.
    case onCancelTap
    case onEditTap
    /// Edit mode of an existing training: asks before deleting it.
    case onDeleteTap
    case onDeleteConfirm
    case onDeleteDismiss
    case onStartTap
    /// "Go to <training>" while another training's workout blocks starting this one.
    case onGoToActiveWorkoutTap
}

enum TrainingEvent: UiEvent {
    case navigateToExerciseLibrary
    case close
    /// [restExerciseIndex]: a rest is in progress, open the exercise showing its timer.
    case navigateToWorkout(restExerciseIndex: Int?)
    case showError(LocalizedStringResource)
}

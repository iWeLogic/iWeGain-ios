import Foundation

struct EditWorkoutState: Equatable {
    /// false until the workout is loaded; the screen stays empty until then.
    var isLoaded = false
    var title = ""
    /// Muscle groups of the exercises, in workout order.
    var muscles: [String] = []
    var exercises: [EditExerciseUi] = []
    /// Non-nil while the set sheet is open.
    var logSet: LogSetUi?
    /// Non-nil while "Delete Bench Press?" is open.
    var deleteExercise: DeleteExerciseUi?
    var isDiscardConfirmOpen = false
    var isDeleteConfirmOpen = false
    /// At least one set is left to save; otherwise the workout can only be deleted.
    var canSave = false
    /// A free workout: sets and exercises can be added and deleted. A training's workout keeps its
    /// exercises and number of sets; only what was logged changes.
    var isFree = false
}

struct EditExerciseUi: Identifiable, Equatable {
    /// Stable while editing, so the list keeps its items when exercises are removed.
    let key: String
    let icon: String
    let name: String
    /// "Chest · Barbell".
    let subtitle: String
    /// "80 kg · × 10", or "Skipped · —".
    let sets: [ExerciseResultSet]

    var id: String { key }
}

struct DeleteExerciseUi: Equatable {
    let key: String
    let name: String
    let setCount: Int
}

enum EditWorkoutAction {
    case onAppear
    /// Cancel: asks before dropping changes.
    case onCancelTap
    case onSaveTap
    case onDiscardConfirm
    case onDiscardDismiss

    case onSetTap(exerciseKey: String, setIndex: Int)
    case onAddSetTap(exerciseKey: String)
    /// Input, Save, Delete and Dismiss of the set sheet.
    case onLogSet(LogSetAction)

    case onDeleteExerciseTap(exerciseKey: String)
    case onDeleteExerciseConfirm
    case onDeleteExerciseDismiss

    case onAddExerciseTap
    case onExercisePicked(id: String)

    case onDeleteWorkoutTap
    case onDeleteWorkoutConfirm
    case onDeleteWorkoutDismiss
}

enum EditWorkoutEvent: UiEvent {
    case close
    case navigateToExerciseLibrary
    case showError(LocalizedStringResource)
}

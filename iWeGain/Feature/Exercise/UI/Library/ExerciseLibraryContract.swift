import Foundation

struct ExerciseLibraryState: Equatable {
    var query = ""
    /// nil means "All".
    var selectedMuscleGroup: MuscleGroup?
    var sections: [ExerciseSectionUi] = []
    var isLoading = true
    /// The exercise sheet (create or edit); nil while it's closed.
    var form: ExerciseFormState?

    var isEmpty: Bool { !isLoading && sections.isEmpty }
}

struct ExerciseSectionUi: Identifiable, Equatable {
    var id: MuscleGroup { muscleGroup }
    let muscleGroup: MuscleGroup
    let exercises: [ExerciseRowUi]
}

struct ExerciseRowUi: Identifiable, Equatable {
    let id: String
    let icon: String
    let name: String
    /// "Chest · Barbell".
    let subtitle: String
    /// Custom exercises can be edited.
    let isCustom: Bool
}

/// The exercise sheet's form.
struct ExerciseFormState: Equatable {
    /// Set when editing an existing custom exercise; nil when creating a new one.
    var editingExerciseId: String?
    var name = ""
    /// nil until the user picks one; the sheet then shows an empty icon tile.
    var icon: ItemIcon?
    var muscleGroup: MuscleGroup?
    var equipment: Equipment?
    var isIconPickerOpen = false
    /// Submit was pressed with something missing: from then on, empty required parts are marked.
    var showMissing = false

    var isEditing: Bool { editingExerciseId != nil }
    var isIconMissing: Bool { showMissing && icon == nil }
    var isNameMissing: Bool { showMissing && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isMuscleGroupMissing: Bool { showMissing && muscleGroup == nil }
    var isEquipmentMissing: Bool { showMissing && equipment == nil }
}

enum ExerciseLibraryAction {
    case onAppear
    case onQueryChange(String)
    case onMuscleGroupTap(MuscleGroup?)
    case onExerciseTap(id: String)

    // Exercise sheet
    case onCreateCustomTap
    case onEditCustomTap(id: String)
    case onFormDismiss
    case onFormNameChange(String)
    case onFormIconTap
    case onFormIconSelect(ItemIcon)
    case onFormIconDismiss
    case onFormMuscleGroupTap(MuscleGroup)
    case onFormEquipmentTap(Equipment)
    case onFormSubmit
}

enum ExerciseLibraryEvent: UiEvent {
    case exercisePicked(id: String)
    case showError(LocalizedStringResource)
}

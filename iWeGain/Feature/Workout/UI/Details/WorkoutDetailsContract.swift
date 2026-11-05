struct WorkoutDetailsState: Equatable {
    /// false until the workout is loaded; the screen stays empty until then.
    var isLoaded = false
    var title = ""
    /// The training's icon, next to its name.
    var icon: String?
    /// "Mon, Sep 28 · 18:05 – 19:17".
    var date = ""
    /// Muscle groups of the exercises, in workout order.
    var muscles: [String] = []
    var duration: DetailsStatUi?
    var volume: DetailsStatUi?
    var sets: DetailsStatUi?
    var records: DetailsStatUi?
    var exercises: [DetailsExerciseUi] = []
    /// The "Delete this workout?" confirmation is open.
    var isDeleteConfirmOpen = false
}

/// One KPI tile: "Volume / 12,450 kg / +4% vs last Push Day". [isPositive] colors the caption green.
struct DetailsStatUi: Equatable {
    let value: String
    let caption: String
    var isPositive = false
}

struct DetailsExerciseUi: Identifiable, Equatable {
    let index: Int
    /// The exercise's own picture.
    let icon: String
    let name: String
    /// "4 sets · Best 100 kg × 5".
    let subtitle: String
    /// The best set beats every earlier workout.
    let isRecord: Bool
    let sets: [ExerciseResultSet]

    var id: Int { index }
}

enum WorkoutDetailsAction {
    case onAppear
    case onEditTap
    case onDeleteTap
    case onDeleteConfirm
    case onDeleteDismiss
}

enum WorkoutDetailsEvent: UiEvent {
    case navigateToEdit
    /// The workout is gone (deleted here or elsewhere).
    case close
}

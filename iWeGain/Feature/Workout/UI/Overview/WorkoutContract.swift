import Foundation

struct WorkoutState: Equatable {
    /// The active workout is shown; until then the content stays hidden.
    var isLoaded = false
    var title = ""
    /// The training's icon, next to its name.
    var icon: String?
    /// "Started 18:05", or "Not started yet" for a free workout waiting for "Start workout".
    var startedAt = ""
    /// "24:13".
    var elapsed = ""
    var setsProgress = ""
    var setsCaption = ""
    var volume = ""
    var exercises: [WorkoutExerciseUi] = []
    /// Every set is done or skipped: Finish workout turns into the primary button.
    var allSetsDone = false
    /// Non-nil while the Finish workout sheet is open.
    var finish: FinishSummaryUi?
    /// The free workout's name in the Finish sheet.
    var finishName = ""
    /// Started without a training (or switched): exercises can be added.
    var isFree = false
    /// The "Switch to free workout?" confirmation is open.
    var isSwitchConfirmOpen = false
    /// false for a free workout before "Start workout": the clock waits and the button starts it.
    var isStarted = true
}

struct WorkoutExerciseUi: Identifiable, Equatable {
    /// Index in the workout; the row's identity, so it slides to its new place when it starts.
    let index: Int
    /// The exercise's own picture.
    let icon: String
    let name: String
    let subtitle: String
    let status: WorkoutExerciseStatus
    /// Share of its sets that were done, drawn as the pie of a `.partial` row.
    var doneShare: Double = 1

    var id: Int { index }
}

enum WorkoutExerciseStatus: Equatable {
    case done
    /// No sets left, but some were skipped: a pie of the done share instead of the ✓.
    case partial
    case active, upcoming, skipped
}

struct FinishSummaryUi: Equatable {
    let doneSets: Int
    let totalSets: Int
    let unfinished: [UnfinishedExerciseUi]
    /// A free workout: the sheet asks for its name and offers to save it as a training.
    var isFree = false
    var saveAsTraining = false
}

struct UnfinishedExerciseUi: Equatable, Identifiable {
    let id: Int
    let name: String
    /// "2 sets left".
    let setsLeft: String
}

enum WorkoutAction {
    case onAppear
    case onExerciseTap(index: Int)
    /// Free workouts: starts the clock (and lets exercises start).
    case onStartWorkoutTap
    case onFinishTap
    case onFinishConfirm
    case onFinishDismiss
    case onFinishNameChange(String)
    case onSaveAsTrainingChange(Bool)
    /// Free workouts: pick an exercise from the library.
    case onAddExerciseTap
    case onExercisePicked(id: String)
    /// A training workout: make it free, so exercises and sets can be added (asks first).
    case onSwitchToFreeTap
    case onSwitchToFreeConfirm
    case onSwitchToFreeDismiss
}

enum WorkoutEvent: UiEvent {
    case navigateToExercise(index: Int)
    case navigateToExerciseLibrary
    /// The workout was finished, or there is no active workout any more.
    case close
    case showError(LocalizedStringResource)
}

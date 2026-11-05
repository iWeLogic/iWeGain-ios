import Foundation

struct ExerciseState: Equatable {
    /// The exercise is shown; until then the content stays hidden.
    var isLoaded = false
    var elapsed = ""
    var name = ""
    /// "Shoulders · Barbell · Exercise 2 of 3".
    var subtitle = ""
    var sets: [SetRowUi] = []
    /// "Rest 2 min between sets".
    var restInfo: String?
    var phase: ExercisePhase = .ready
    /// Another exercise is running, so starting this one means changing exercise (see the dialog).
    var blockingExercise: BlockingExerciseUi?
    /// The "Change exercise" dialog is open (only while [blockingExercise] is set).
    var isChangeDialogOpen = false
    /// Set number of the "Set 2 skipped · Undo" pill, nil when hidden.
    var skippedSetNumber: Int?
    /// The rest timer card; at 0:00 while this exercise has no rest running.
    var rest = RestUi()
    /// Non-nil while the Log Set sheet is open.
    var logSet: LogSetUi?
    /// A free workout: "Add set" under the sets (while no other exercise runs).
    var canAddSet = false
    /// A free workout: "Remove exercise" next to the name.
    var canRemoveExercise = false
    /// The "Remove Bench Press?" confirmation is open.
    var isRemoveConfirmOpen = false
    /// false while a free workout waits for "Start workout": exercises can't start yet.
    var isWorkoutStarted = true
}

/// [ready]: not started yet; [running]: started, sets being logged; [done]: no sets left; [skipped]: skipped with sets left.
enum ExercisePhase: Equatable {
    case ready, running, done, skipped
}

struct RestUi: Equatable {
    /// A rest of this exercise exists (running, paused or over); otherwise the timer just shows 0:00.
    var isActive = false
    /// When the rest ends; the ring is drawn from it every frame.
    var endsAt = Date.distantPast
    var durationSeconds = 0
    /// Time left of a paused rest, which the ring shows standing still; nil while counting down.
    var pausedRemaining: TimeInterval?
    /// "1:24".
    var remaining = "0:00"
    /// "2:00": the running rest, or the exercise's rest time.
    var total = "0:00"
    var isOver = true

    var isPaused: Bool { pausedRemaining != nil }

    /// Counting down or paused: Pause, Cancel and ±15 s apply.
    var isRunning: Bool { isActive && !isOver }

    /// "REST", "PAUSED" or "REST OVER" above the time.
    var label: String {
        Strings.text(isActive && isOver ? "rest_over" : isPaused ? "rest_paused" : "rest_label")
    }

    /// Share of the rest still left at [now], for the ring.
    func progress(at now: Date) -> Double {
        guard durationSeconds > 0 else { return 0 }
        let left = pausedRemaining ?? endsAt.timeIntervalSince(now)
        return min(1, max(0, left / Double(durationSeconds)))
    }
}

struct BlockingExerciseUi: Equatable {
    let index: Int
    let name: String
}

struct SetRowUi: Equatable, Identifiable {
    let number: Int
    let weight: String
    let reps: String
    let status: WorkoutSetStatus
    /// A skipped set that can be tried again (not while another exercise is running).
    var canRetry = false
    /// A done set whose weight and reps can be changed.
    var canEdit = false

    var id: Int { number }
}

enum WorkoutSetStatus: Equatable {
    case done, current, upcoming, skipped
}

enum ExerciseAction {
    case onAppear
    case onCompleteSetTap
    case onSkipSetTap
    case onUndoSkipTap
    /// A skipped set was tapped: try it again.
    case onRetrySetTap(number: Int)
    /// "Start exercise", also for a skipped exercise.
    case onStartExerciseTap
    /// "Change exercise" while another exercise runs: opens the dialog.
    case onChangeExerciseTap
    /// Dialog: "Go to <running exercise>".
    case onGoToRunningTap
    /// Dialog: set the running exercise aside and start this one.
    case onChangeExerciseConfirm
    case onChangeExerciseDismiss
    /// "Back to workout" once the exercise is done.
    case onContinueTap
    /// Free workouts: one more set for this exercise.
    case onAddSetTap
    /// Free workouts: take this exercise out of the workout (asks first).
    case onRemoveExerciseTap
    case onRemoveExerciseConfirm
    case onRemoveExerciseDismiss
    /// A done set's pencil was tapped: change what was logged.
    case onEditSetTap(number: Int)
    case onRestMinusTap
    case onRestPlusTap
    /// Pause, or Resume while paused.
    case onRestPauseTap
    case onRestCancelTap
    /// Input, Save and Cancel of the Log Set sheet.
    case onLogSet(LogSetAction)
}

enum ExerciseEvent: UiEvent {
    case backToWorkout
    /// The rest countdown just reached zero.
    case restOver
    case navigateToExercise(index: Int)
    case showError(LocalizedStringResource)
}

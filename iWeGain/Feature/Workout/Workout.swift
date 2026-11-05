import Foundation

/// A training being performed (or already finished): every planned set with what was actually lifted.
nonisolated struct Workout: Identifiable, Hashable, Sendable {
    /// [startedAt] of a free workout whose "Start workout" wasn't tapped yet (-1 ms, as on Android).
    static let notStarted = Date(epochMillis: -1)

    let id: String
    var userId: String
    /// nil for a free workout, started without a training (or switched to one); exercises and sets can be added to it.
    var trainingId: String?
    var trainingName: String
    var trainingIcon: ItemIcon
    /// [notStarted] for a free workout whose "Start workout" wasn't tapped yet.
    var startedAt: Date
    /// nil while the workout is in progress.
    var finishedAt: Date?
    var exercises: [WorkoutExercise]
    /// Rest running after the last saved set; nil when no rest is in progress.
    var rest: RestTimer?
    /// When every set was done or skipped; the workout clock stops here. nil while sets are left.
    var setsDoneAt: Date?

    /// A free workout waits for "Start workout": until then its [startedAt] is [notStarted] and the
    /// clock stays at 0:00. A training's workout runs from the moment it's started.
    var isClockStarted: Bool { startedAt != Self.notStarted }

    /// The workout clock at [now]: from the start until now, or until the last set once nothing is left.
    func elapsed(now: Date) -> TimeInterval {
        guard isClockStarted else { return 0 }
        return max(0, (setsDoneAt ?? now).timeIntervalSince(startedAt))
    }

    var isFree: Bool { trainingId == nil }

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var doneSetCount: Int { exercises.reduce(0) { $0 + $1.doneCount } }
    /// Skipped sets, counting the open sets of skipped exercises too.
    var skippedSetCount: Int { exercises.reduce(0) { $0 + $1.skippedCount + ($1.isSkipped ? $1.pendingCount : 0) } }

    /// Total weight × reps of the completed sets, in kilograms.
    var volumeKg: Double { exercises.reduce(0) { total, exercise in total + exercise.sets.reduce(0) { $0 + $1.volumeKg } } }

    /// The exercise being performed. Exercises can be done in any order, but only one runs at a time:
    /// another can start once this one has no sets left or is skipped.
    var runningExerciseIndex: Int? { exercises.firstIndex { $0.isRunning } }

    /// Exercise indices in the order they are listed: the finished and the running ones first, in the order
    /// they were (last) started, then the others in training order. So an exercise moves up behind the
    /// finished ones when it starts.
    var displayOrder: [Int] {
        let started = exercises.indices.filter { index in
            let exercise = exercises[index]
            return exercise.startedAt != nil && (exercise.isRunning || exercise.pendingCount == 0)
        }
        let others = exercises.indices.filter { !started.contains($0) }
        // Ties keep training order, like Kotlin's stable sortedBy.
        let sortedStarted = started.sorted { (exercises[$0].startedAt!, $0) < (exercises[$1].startedAt!, $1) }
        return sortedStarted + others
    }

    /// A rest follows the set when the exercise has a rest time and another set of it is still to do.
    /// After its last set there is no rest: the user goes back to the overview to pick the next exercise.
    func restFollows(exerciseIndex: Int, setIndex: Int) -> Bool {
        let exercise = exercises[exerciseIndex]
        let moreSetsHere = exercise.sets.indices.contains { $0 != setIndex && exercise.sets[$0].status == .pending }
        return exercise.restSeconds > 0 && moreSetsHere
    }
}

nonisolated struct WorkoutExercise: Hashable, Sendable {
    var exercise: Exercise
    var restSeconds: Int
    var sets: [WorkoutSet]
    var isSkipped = false
    /// When the exercise was last started or continued; nil until the user taps Start exercise.
    var startedAt: Date?

    var doneCount: Int { sets.count { $0.status == .done } }
    var skippedCount: Int { sets.count { $0.status == .skipped } }
    var pendingCount: Int { sets.count { $0.status == .pending } }

    /// Still has sets to do.
    var isOpen: Bool { !isSkipped && pendingCount > 0 }

    /// Started and not finished yet.
    var isRunning: Bool { startedAt != nil && isOpen }

    /// Index of the next set to do, or nil when every set is done or skipped.
    var currentSetIndex: Int? { sets.firstIndex { $0.status == .pending } }

    /// The heaviest completed set (most reps on a tie).
    var bestSet: WorkoutSet? {
        sets.filter { $0.status == .done }
            .max { ($0.weightKg ?? 0, $0.reps ?? 0) < ($1.weightKg ?? 0, $1.reps ?? 0) }
    }
}

/// One set. [targetWeightKg] and [targetReps] are the suggestion shown before the set is done
/// (last time's result, or the previous set of this workout); [weightKg] and [reps] are what was logged.
nonisolated struct WorkoutSet: Hashable, Sendable {
    var status: SetStatus = .pending
    var targetWeightKg: Double
    var targetReps: Int
    var weightKg: Double?
    var reps: Int?

    var volumeKg: Double { status == .done ? (weightKg ?? 0) * Double(reps ?? 0) : 0 }
}

/// Raw values are what Android and Firestore store.
nonisolated enum SetStatus: String, Codable, Sendable {
    case pending = "Pending", done = "Done", skipped = "Skipped"
}

/// Rest between sets, or before the first set of an exercise; [endsAt] is a point in time, so the timer
/// keeps running while the app is in the background.
nonisolated struct RestTimer: Hashable, Sendable {
    /// [savedSetIndex] of the rest that starts with an exercise, before its first set.
    static let beforeFirstSet = -1

    var endsAt: Date
    var durationSeconds: Int
    /// The exercise whose screen shows the timer: the one of the set just saved, or the one just started.
    var savedExerciseIndex: Int
    /// The set that was just saved, or [beforeFirstSet] for the rest when an exercise starts.
    var savedSetIndex: Int
    /// When the rest was paused; nil while it counts down. Resuming moves [endsAt] on by the pause.
    var pausedAt: Date?

    var isPaused: Bool { pausedAt != nil }

    /// Time left at [now]; frozen while paused.
    func remaining(now: Date) -> TimeInterval { max(0, endsAt.timeIntervalSince(pausedAt ?? now)) }

    func isOver(now: Date) -> Bool { remaining(now: now) == 0 }
}

/// A previous result of one exercise, for "Last time" hints.
nonisolated struct ExerciseHistory: Hashable, Sendable {
    /// The workout's start.
    var date: Date
    /// Completed sets in order; skipped sets are left out.
    var sets: [WorkoutSet]
}

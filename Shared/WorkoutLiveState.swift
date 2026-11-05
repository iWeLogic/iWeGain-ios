import Foundation

/// What the workout's Live Activity shows (the counterpart of Android's ongoing workout notification,
/// Figma "Workout Notification"). Compiled into the app and the widget extension. The app fills in every
/// text, so the extension needs no strings of its own; the timers are dates the system ticks.
nonisolated struct WorkoutLiveState: Codable, Hashable, Sendable {
    nonisolated enum Kind: String, Codable, Hashable, Sendable {
        /// A set of the running exercise is next: Complete (opens Log Set), +15 s, Skip.
        case set
        /// A rest is counting down, or paused: +15 s, Skip rest.
        case rest
        /// The rest ended and the next set is due: Complete, +15 s, Skip.
        case restOver
        /// No exercise is running: choose the next one in the app.
        case chooseExercise
        /// Every set is done or skipped: finish the workout in the app.
        case allDone
    }

    /// Button titles and labels, in the app's language.
    nonisolated struct Labels: Codable, Hashable, Sendable {
        var complete: String
        var skipSet: String
        var addRest: String
        var skipRest: String
        var restOver: String
    }

    var kind: Kind
    var trainingName: String
    /// "Push Day", "Rest", "Rest paused · 1:12" or "Rest over".
    var title: String
    /// "Bench Press · Set 2 of 4 · 60 kg × 8", "Next: Bench Press · Set 2 of 4", "Choose the next exercise · 3 / 10 sets".
    var text: String
    /// [text] once a rest is over: the Live Activity switches to it by itself when the rest ends while the
    /// app can't update it (the activity goes stale at the end of the rest).
    var restOverText: String
    /// The workout clock counts up from here.
    var startedAt: Date
    /// The workout clock stopped at the last set; nil while it runs.
    var stoppedElapsedSeconds: Int?
    var doneSets: Int
    var totalSets: Int
    /// The running exercise; nil when the next exercise isn't chosen yet.
    var exerciseIndex: Int?
    /// The exercise whose screen shows the rest timer.
    var restExerciseIndex: Int?
    var restEndsAt: Date?
    var restDurationSeconds: Int?
    /// Seconds left of a paused rest; nil while it counts down (or there is no rest).
    var restPausedSeconds: Int?
    var labels: Labels

    /// A rest counting down: the system ticks it to [restEndsAt].
    var countingRest: ClosedRange<Date>? {
        guard kind == .rest, restPausedSeconds == nil, let restEndsAt, let restDurationSeconds else { return nil }
        let start = restEndsAt.addingTimeInterval(-TimeInterval(restDurationSeconds))
        return start < restEndsAt ? start...restEndsAt : nil
    }

    /// "1:24", "24:13" or "1:04:13", like the app's clocks.
    static func clock(_ seconds: Int) -> String {
        let duration = Duration.seconds(max(0, seconds))
        return duration.formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }

    /// The same state once the counting rest is over, as the app would show it.
    var afterRest: WorkoutLiveState {
        guard countingRest != nil else { return self }
        var state = self
        state.kind = exerciseIndex == nil ? .chooseExercise : .restOver
        state.title = exerciseIndex == nil ? trainingName : labels.restOver
        state.text = restOverText
        return state
    }
}

/// Where a tap on the Live Activity takes the app: `iwegain://workout`, `iwegain://workout/exercise/2`,
/// or `iwegain://workout/exercise/2/log-set` (Complete: the exercise with its Log Set sheet).
nonisolated enum WorkoutLink: Equatable {
    static let scheme = "iwegain"

    case overview
    case exercise(index: Int, opensLogSet: Bool)

    var url: URL {
        switch self {
        case .overview: URL(string: "\(Self.scheme)://workout")!
        case .exercise(let index, let opensLogSet):
            URL(string: "\(Self.scheme)://workout/exercise/\(index)\(opensLogSet ? "/log-set" : "")")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == "workout" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch parts.count {
        case 0: self = .overview
        case 2, 3:
            guard parts[0] == "exercise", let index = Int(parts[1]), index >= 0 else { return nil }
            if parts.count == 3 && parts[2] != "log-set" { return nil }
            self = .exercise(index: index, opensLogSet: parts.count == 3)
        default: return nil
        }
    }
}

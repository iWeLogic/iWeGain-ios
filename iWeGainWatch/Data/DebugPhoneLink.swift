#if DEBUG
import Foundation

/// A pretend phone for screenshots, chosen with `-debug-workout set|rest|paused|rest-over|log-set|no-workout|choose-exercise|all-done|not-connected`.
final class DebugPhoneLink: PhoneLink {
    var onWorkout: ((WatchWorkoutState) -> Void)?
    var onReachabilityChange: ((Bool) -> Void)?
    private let workout: WatchWorkoutState
    private let isReachable: Bool

    private init(workout: WatchWorkoutState, isReachable: Bool = true) {
        self.workout = workout
        self.isReachable = isReachable
    }

    static var opensLogSet: Bool { route == "log-set" }

    private static var route: String? {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.firstIndex(of: "-debug-workout").flatMap { arguments[safe: $0 + 1] }
    }

    static func fromLaunchArguments() -> DebugPhoneLink? {
        var set = WatchWorkoutState(
            isActive: true, exerciseIndex: 1, setIndex: 2, exerciseName: "Overhead Press", setCount: 3,
            targetWeightKg: 60, targetReps: 6, restFollows: true
        )
        switch route {
        case nil: return nil
        case "rest":
            set.restEndsAt = Date().addingTimeInterval(84)
            set.restDurationSeconds = 120
        case "paused":
            set.restEndsAt = Date().addingTimeInterval(84)
            set.restDurationSeconds = 120
            set.restPausedRemaining = 84
        case "rest-over":
            set.restEndsAt = Date().addingTimeInterval(-1)
            set.restDurationSeconds = 120
        case "no-workout": return DebugPhoneLink(workout: WatchWorkoutState(isActive: false))
        case "choose-exercise": return DebugPhoneLink(workout: WatchWorkoutState(isActive: true))
        case "all-done": return DebugPhoneLink(workout: WatchWorkoutState(isActive: true, allSetsDone: true))
        case "not-connected": return DebugPhoneLink(workout: set, isReachable: false)
        default: break
        }
        return DebugPhoneLink(workout: set)
    }

    func start() {
        onReachabilityChange?(isReachable)
        onWorkout?(workout)
    }

    func send(_ command: WatchCommand) async -> Bool { isReachable }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif

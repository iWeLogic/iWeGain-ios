import Foundation

/// The active workout as the watch shows it (Figma "Watch · Wear OS"): the due set of the running exercise and
/// the rest. The watch counts the rest down itself from [restEndsAt], so this only changes when the workout does.
nonisolated struct WatchWorkoutState: Equatable, Sendable {
    var isActive: Bool
    /// The running exercise and its due set; nil when no exercise runs.
    var exerciseIndex: Int?
    var setIndex: Int?
    var exerciseName = ""
    var setCount = 0
    var targetWeightKg: Double?
    var targetReps: Int?
    /// Logging the due set starts a rest ("Save & rest").
    var restFollows = false
    /// nil without a rest.
    var restEndsAt: Date?
    var restDurationSeconds = 0
    /// Time left of a paused rest; nil while it counts down (or there is no rest).
    var restPausedRemaining: TimeInterval?
    /// Every set is done or skipped: the workout is finished on the phone.
    var allSetsDone = false
    var weightUnit = WeightUnit.kg

    var setNumber: Int? { setIndex.map { $0 + 1 } }

    var hasRest: Bool { restEndsAt != nil }

    /// Whether the rest is counting down, so the watch has something to follow.
    var countingRestEnd: Date? { restPausedRemaining == nil ? restEndsAt : nil }

    func restRemaining(now: Date) -> TimeInterval {
        restPausedRemaining ?? max(0, (restEndsAt ?? now).timeIntervalSince(now))
    }

    func isRestOver(now: Date) -> Bool { hasRest && restRemaining(now: now) == 0 }
}

/// What the phone and the watch app exchange over WatchConnectivity (the counterpart of Android's `WatchProtocol`).
/// The phone sends the state as its application context, kept for the watch until it can be delivered, and
/// also as a message when the watch is reachable, which arrives right away. Commands are messages to the
/// phone, which wake its app; the reply carries the state after the command.
nonisolated enum WatchProtocol {
    fileprivate enum Key {
        static let path = "path"
        static let sentAt = "sentAt"
        static let active = "active"
        static let exerciseIndex = "exerciseIndex"
        static let setIndex = "setIndex"
        static let exerciseName = "exerciseName"
        static let setCount = "setCount"
        static let targetWeightKg = "targetWeightKg"
        static let targetReps = "targetReps"
        static let restFollows = "restFollows"
        static let restEndsAt = "restEndsAt"
        static let restDurationSeconds = "restDurationSeconds"
        static let restPausedRemaining = "restPausedRemaining"
        static let allSetsDone = "allSetsDone"
        static let weightUnit = "weightUnit"
        static let weightKg = "weightKg"
        static let reps = "reps"
        static let deltaSeconds = "deltaSeconds"
    }

    fileprivate enum Path {
        static let logSet = "/workout/log-set"
        static let adjustRest = "/workout/adjust-rest"
        static let requestState = "/workout/request-state"
    }
}

extension WatchWorkoutState {
    private typealias Key = WatchProtocol.Key

    /// [sentAt] puts the phone's updates in order, since they arrive over two channels.
    nonisolated func dictionary(sentAt: Date) -> [String: Any] {
        var fields: [String: Any] = [
            Key.sentAt: sentAt.timeIntervalSince1970,
            Key.active: isActive,
            Key.exerciseName: exerciseName,
            Key.setCount: setCount,
            Key.restFollows: restFollows,
            Key.restDurationSeconds: restDurationSeconds,
            Key.allSetsDone: allSetsDone,
            Key.weightUnit: weightUnit.rawValue,
        ]
        fields[Key.exerciseIndex] = exerciseIndex
        fields[Key.setIndex] = setIndex
        fields[Key.targetWeightKg] = targetWeightKg
        fields[Key.targetReps] = targetReps
        fields[Key.restEndsAt] = restEndsAt?.timeIntervalSince1970
        fields[Key.restPausedRemaining] = restPausedRemaining
        return fields
    }

    /// nil when [fields] isn't a workout state (an empty application context, before the phone sent one).
    nonisolated init?(dictionary fields: [String: Any]) {
        guard let isActive = fields[Key.active] as? Bool else { return nil }
        self.init(
            isActive: isActive,
            exerciseIndex: fields[Key.exerciseIndex] as? Int,
            setIndex: fields[Key.setIndex] as? Int,
            exerciseName: fields[Key.exerciseName] as? String ?? "",
            setCount: fields[Key.setCount] as? Int ?? 0,
            targetWeightKg: fields[Key.targetWeightKg] as? Double,
            targetReps: fields[Key.targetReps] as? Int,
            restFollows: fields[Key.restFollows] as? Bool ?? false,
            restEndsAt: (fields[Key.restEndsAt] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
            restDurationSeconds: fields[Key.restDurationSeconds] as? Int ?? 0,
            restPausedRemaining: fields[Key.restPausedRemaining] as? TimeInterval,
            allSetsDone: fields[Key.allSetsDone] as? Bool ?? false,
            weightUnit: (fields[Key.weightUnit] as? String).flatMap(WeightUnit.init(rawValue:)) ?? .kg
        )
    }

    nonisolated static func sentAt(in fields: [String: Any]) -> Date? {
        (fields[Key.sentAt] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
    }
}

/// What the watch asks the phone to do.
nonisolated enum WatchCommand: Equatable, Sendable {
    /// Save in the watch's Log Set.
    case logSet(exerciseIndex: Int, setIndex: Int, weightKg: Double, reps: Int)
    /// −15 s / +15 s on the rest.
    case adjustRest(deltaSeconds: Int)
    /// The watch came on screen: sends back the current state, however late the application context is.
    case requestState

    private typealias Key = WatchProtocol.Key
    private typealias Path = WatchProtocol.Path

    var dictionary: [String: Any] {
        switch self {
        case .logSet(let exerciseIndex, let setIndex, let weightKg, let reps):
            [Key.path: Path.logSet, Key.exerciseIndex: exerciseIndex, Key.setIndex: setIndex, Key.weightKg: weightKg, Key.reps: reps]
        case .adjustRest(let deltaSeconds):
            [Key.path: Path.adjustRest, Key.deltaSeconds: deltaSeconds]
        case .requestState:
            [Key.path: Path.requestState]
        }
    }

    /// nil for anything that isn't a valid command.
    init?(dictionary fields: [String: Any]) {
        switch fields[Key.path] as? String {
        case Path.logSet:
            guard let exerciseIndex = fields[Key.exerciseIndex] as? Int,
                  let setIndex = fields[Key.setIndex] as? Int,
                  let weightKg = fields[Key.weightKg] as? Double, weightKg >= 0,
                  let reps = fields[Key.reps] as? Int, reps > 0 else { return nil }
            self = .logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weightKg: weightKg, reps: reps)
        case Path.adjustRest:
            guard let deltaSeconds = fields[Key.deltaSeconds] as? Int, deltaSeconds != 0 else { return nil }
            self = .adjustRest(deltaSeconds: deltaSeconds)
        case Path.requestState:
            self = .requestState
        default:
            return nil
        }
    }
}

/// Figma "55 · Watch · Log Set": starts at the target; − / + change the weight by [WeightUnit.step] and reps by 1.
nonisolated struct WatchLogSet: Equatable, Sendable {
    let exerciseIndex: Int
    let setIndex: Int
    /// In [unit].
    private(set) var weight: Double
    private(set) var reps: Int
    let unit: WeightUnit
    let restFollows: Bool

    var setNumber: Int { setIndex + 1 }
    var canDecreaseWeight: Bool { weight > 0 }
    var canDecreaseReps: Bool { reps > 1 }
    var weightText: String { Weights.number(weight) }

    /// nil when [workout] has no due set.
    init?(workout: WatchWorkoutState) {
        guard let exerciseIndex = workout.exerciseIndex, let setIndex = workout.setIndex else { return nil }
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        weight = Double(workout.weightUnit.weightNumber(workout.targetWeightKg ?? 0)) ?? 0
        reps = workout.targetReps ?? 1
        unit = workout.weightUnit
        restFollows = workout.restFollows
    }

    /// Rounded to 0.01, so steps on a value like 126.8 lb don't drift into 131.79999.
    mutating func changeWeight(steps: Int) {
        weight = max(0, ((weight + Double(steps) * unit.step) * 100).rounded() / 100)
    }

    mutating func changeReps(delta: Int) {
        reps = max(1, reps + delta)
    }

    /// The set being logged was logged or skipped on the phone meanwhile.
    func isOutOfDate(for workout: WatchWorkoutState) -> Bool {
        workout.exerciseIndex != exerciseIndex || workout.setIndex != setIndex
    }

    var command: WatchCommand {
        .logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weightKg: unit.toKg(weight), reps: reps)
    }
}

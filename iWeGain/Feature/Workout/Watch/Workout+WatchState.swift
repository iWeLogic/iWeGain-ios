import Foundation
import OSLog

extension Optional where Wrapped == Workout {
    /// What the watch shows for this workout at [now]; nil and a free workout that hasn't started show no workout.
    func watchState(unit: WeightUnit, now: Date) -> WatchWorkoutState {
        guard let workout = self, workout.isClockStarted else { return WatchWorkoutState(isActive: false, weightUnit: unit) }
        let exerciseIndex = workout.runningExerciseIndex
        let exercise = exerciseIndex.map { workout.exercises[$0] }
        let setIndex = exercise?.currentSetIndex
        let set = setIndex.flatMap { exercise?.sets[$0] }
        let rest = workout.rest
        return WatchWorkoutState(
            isActive: true,
            exerciseIndex: setIndex == nil ? nil : exerciseIndex,
            setIndex: setIndex,
            exerciseName: exercise?.exercise.name ?? "",
            setCount: exercise?.sets.count ?? 0,
            targetWeightKg: set?.targetWeightKg,
            targetReps: set?.targetReps,
            restFollows: exerciseIndex.flatMap { index in setIndex.map { workout.restFollows(exerciseIndex: index, setIndex: $0) } } ?? false,
            restEndsAt: rest?.endsAt,
            restDurationSeconds: rest?.durationSeconds ?? 0,
            restPausedRemaining: rest.flatMap { $0.isPaused ? $0.remaining(now: now) : nil },
            allSetsDone: workout.setsDoneAt != nil,
            weightUnit: unit
        )
    }
}

extension WorkoutRepository {
    /// Applies what the watch asked for; the watch and the Live Activity follow through the active workout.
    func perform(_ command: WatchCommand) {
        do {
            switch command {
            case .logSet(let exerciseIndex, let setIndex, let weightKg, let reps):
                try logSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weightKg: weightKg, reps: reps)
            case .adjustRest(let deltaSeconds):
                try adjustRest(deltaSeconds: deltaSeconds)
            case .requestState:
                break
            }
        } catch {
            Logger(subsystem: "com.iwelogic.gain", category: "Watch").error("Watch command failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

import Foundation

extension Workout {
    /// What the Live Activity shows for this workout at [now]; the rules of Android's `notificationContent`.
    func liveState(unit: WeightUnit, now: Date) -> WorkoutLiveState {
        let exerciseIndex = runningExerciseIndex
        let exercise = exerciseIndex.map { exercises[$0] }
        let setIndex = exercise?.currentSetIndex
        let set = setIndex.flatMap { exercise?.sets[$0] }
        let kind: WorkoutLiveState.Kind = if let rest, !rest.isOver(now: now) {
            .rest
        } else if set == nil && setsDoneAt != nil {
            .allDone
        } else if set == nil {
            .chooseExercise
        } else if rest != nil {
            .restOver
        } else {
            .set
        }
        let setText: String? = if let exercise, let setIndex {
            Strings.format("workout_notification_set", exercise.exercise.name, setIndex + 1, exercise.sets.count)
        } else {
            nil
        }
        let target = set.map { unit.setResultText($0.targetWeightKg, reps: $0.targetReps) }
        let chooseText = Strings.format("workout_notification_choose_progress", doneSetCount, setCount)
        let setLine = [setText, target].compactMap { $0 }.joined(separator: " · ")
        let pausedSeconds = rest.flatMap { $0.isPaused ? Int($0.remaining(now: now).rounded(.up)) : nil }
        let title = switch kind {
        case .rest: pausedSeconds.map { Strings.format("workout_notification_rest_paused", Durations.clock($0)) }
            ?? Strings.text("workout_notification_rest")
        case .restOver: Strings.text("workout_notification_rest_over")
        case .set, .chooseExercise, .allDone: trainingName
        }
        let text = switch kind {
        case .rest: setText.map { Strings.format("workout_notification_next", $0) } ?? Strings.text("workout_notification_choose")
        case .chooseExercise: chooseText
        case .allDone: Strings.format("workout_notification_all_done", doneSetCount, setCount)
        case .set, .restOver: setLine
        }
        return WorkoutLiveState(
            kind: kind,
            trainingName: trainingName,
            title: title,
            text: text,
            restOverText: setText == nil ? chooseText : setLine,
            startedAt: startedAt,
            // Stands still at the last set.
            stoppedElapsedSeconds: setsDoneAt != nil || !isClockStarted ? Int(elapsed(now: now)) : nil,
            doneSets: doneSetCount,
            totalSets: setCount,
            exerciseIndex: exerciseIndex,
            restExerciseIndex: rest?.savedExerciseIndex,
            restEndsAt: rest?.endsAt,
            restDurationSeconds: rest?.durationSeconds,
            restPausedSeconds: pausedSeconds,
            labels: WorkoutLiveState.Labels(
                complete: Strings.text("workout_notification_complete_set"),
                skipSet: Strings.text("workout_notification_skip_set"),
                addRest: Strings.text("workout_notification_add_rest"),
                skipRest: Strings.text("workout_notification_skip_rest"),
                restOver: Strings.text("workout_notification_rest_over")
            )
        )
    }
}

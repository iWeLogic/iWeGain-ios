import Foundation

/// The result of a finished workout, compared with the earlier workouts of the same training.
final class WorkoutDetailsViewModel: BaseViewModel<WorkoutDetailsState, WorkoutDetailsAction, WorkoutDetailsEvent> {
    private let workoutId: String
    private let workoutRepository: WorkoutRepository
    private let settingsRepository: SettingsRepository
    private var isObserving = false

    init(workoutId: String, workoutRepository: WorkoutRepository, settingsRepository: SettingsRepository) {
        self.workoutId = workoutId
        self.workoutRepository = workoutRepository
        self.settingsRepository = settingsRepository
        super.init(initialState: WorkoutDetailsState())
    }

    override func onAction(_ action: WorkoutDetailsAction) {
        switch action {
        case .onAppear: observe()
        case .onEditTap: sendEvent(.navigateToEdit)
        case .onDeleteTap: updateState { $0.isDeleteConfirmOpen = true }
        case .onDeleteDismiss: updateState { $0.isDeleteConfirmOpen = false }
        case .onDeleteConfirm:
            // Once it's deleted the workout stops loading, which closes the screen.
            updateState { $0.isDeleteConfirmOpen = false }
            try? workoutRepository.deleteWorkout(id: workoutId)
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            typealias Details = (workout: Workout, finished: [Workout], unit: WeightUnit)
            let details = workoutRepository.observeWorkout(id: workoutId).flatMapLatest { [workoutRepository, settingsRepository] workout -> AsyncStream<Details?> in
                guard let workout else { return AsyncStream { $0.yield(nil); $0.finish() } }
                return combineLatest(workoutRepository.observeFinishedWorkouts(userId: workout.userId), settingsRepository.observeSettings())
                    .map { finished, settings -> Details? in (workout, finished, settings.weightUnit) }
            }
            for await data in details {
                // Deleted (e.g. on another device): nothing left to show.
                guard let (workout, finished, unit) = data else {
                    sendEvent(.close)
                    return
                }
                let built = Self.build(workout, finished: finished, unit: unit)
                updateState { state in
                    let isDeleteConfirmOpen = state.isDeleteConfirmOpen
                    state = built
                    state.isDeleteConfirmOpen = isDeleteConfirmOpen
                }
            }
        }
    }

    static func build(_ workout: Workout, finished: [Workout], unit: WeightUnit) -> WorkoutDetailsState {
        let earlier = finished.filter { $0.id != workout.id && $0.startedAt < workout.startedAt }
        // Newest first. A free workout has no training to compare with.
        let earlierOfTraining = earlier
            .filter { workout.trainingId != nil && $0.trainingId == workout.trainingId }
            .sorted { $0.startedAt > $1.startedAt }
        let last = earlierOfTraining.first
        let recordIndexes = workout.exercises.indices.filter { isRecord(workout.exercises[$0], earlier: earlier) }
        let end = workout.finishedAt ?? workout.startedAt
        var muscles: [MuscleGroup] = []
        for muscle in workout.exercises.map(\.exercise.muscleGroup) where !muscles.contains(muscle) { muscles.append(muscle) }
        return WorkoutDetailsState(
            isLoaded: true,
            title: workout.trainingName,
            icon: workout.trainingIcon.imageName,
            date: Strings.format(
                "workout_details_date",
                Day(workout.startedAt).shortTitle,
                workout.startedAt.formatted(date: .omitted, time: .shortened),
                end.formatted(date: .omitted, time: .shortened)
            ),
            muscles: muscles.map { String(localized: $0.label) },
            duration: durationStat(workout, earlier: earlierOfTraining),
            volume: volumeStat(workout, last: last, unit: unit),
            sets: setsStat(workout, last: last),
            records: recordsStat(workout, recordIndexes: recordIndexes),
            exercises: workout.exercises.enumerated().map { index, exercise in
                exerciseUi(exercise, index: index, isRecord: recordIndexes.contains(index), unit: unit)
            }
        )
    }

    private static func durationStat(_ workout: Workout, earlier: [Workout]) -> DetailsStatUi {
        let minutes = workout.minutes
        guard !earlier.isEmpty else { return DetailsStatUi(value: durationText(minutes), caption: Strings.text("workout_details_first_time")) }
        let average = Double(earlier.map(\.minutes).reduce(0, +)) / Double(earlier.count)
        let diff = minutes - Int(average.rounded())
        return DetailsStatUi(
            value: durationText(minutes),
            caption: Strings.format("workout_details_vs_average", signed(diff, durationText(abs(diff)))),
            // Shorter than usual is the good result; longer stays gray.
            isPositive: diff < 0
        )
    }

    private static func volumeStat(_ workout: Workout, last: Workout?, unit: WeightUnit) -> DetailsStatUi {
        let value = unit.volumeText(workout.volumeKg)
        guard let before = last?.volumeKg, before > 0 else {
            return DetailsStatUi(value: value, caption: Strings.text("workout_details_first_time"))
        }
        let percent = Int(((workout.volumeKg - before) / before * 100).rounded())
        return DetailsStatUi(
            value: value,
            caption: Strings.format("workout_details_vs_last", signed(percent, "\(abs(percent))%"), workout.trainingName),
            isPositive: percent > 0
        )
    }

    private static func setsStat(_ workout: Workout, last: Workout?) -> DetailsStatUi {
        let done = workout.doneSetCount
        let caption: String
        if let last {
            if last.doneSetCount == done {
                caption = Strings.text("workout_details_same_as_last")
            } else {
                let diff = done - last.doneSetCount
                caption = Strings.format("workout_details_sets_vs_last", signed(diff, "\(abs(diff))"))
            }
        } else {
            caption = Strings.format("workout_details_of_planned", workout.setCount)
        }
        return DetailsStatUi(value: done.formatted(), caption: caption, isPositive: last.map { done > $0.doneSetCount } ?? false)
    }

    private static func recordsStat(_ workout: Workout, recordIndexes: [Int]) -> DetailsStatUi {
        DetailsStatUi(
            value: Strings.plural("workout_details_prs", recordIndexes.count),
            caption: recordIndexes.isEmpty
                ? Strings.text("workout_details_no_records")
                : recordIndexes.map { workout.exercises[$0].exercise.name }.joined(separator: ", "),
            isPositive: !recordIndexes.isEmpty
        )
    }

    /// The best set weight beats every earlier workout of this person. The first time an exercise is
    /// done doesn't count, as on Statistics.
    private static func isRecord(_ exercise: WorkoutExercise, earlier: [Workout]) -> Bool {
        guard let best = exercise.sets.filter({ $0.status == .done }).map({ $0.weightKg ?? 0 }).max() else { return false }
        let previousBest = earlier
            .flatMap { $0.exercises.filter { $0.exercise.id == exercise.exercise.id }.flatMap(\.sets) }
            .filter { $0.status == .done }
            .map { $0.weightKg ?? 0 }
            .max()
        guard let previousBest else { return false }
        return best > previousBest
    }

    private static func exerciseUi(_ exercise: WorkoutExercise, index: Int, isRecord: Bool, unit: WeightUnit) -> DetailsExerciseUi {
        let setCount = Strings.plural("training_set_count", exercise.sets.count)
        let subtitle = if let best = exercise.bestSet {
            Strings.format("workout_details_exercise_best", setCount, unit.setResultText(best.weightKg ?? 0, reps: best.reps ?? 0))
        } else {
            Strings.format("workout_details_exercise_skipped", setCount)
        }
        return DetailsExerciseUi(
            index: index,
            icon: exercise.exercise.imageName,
            name: exercise.exercise.name,
            subtitle: subtitle,
            isRecord: isRecord,
            sets: exercise.sets.enumerated().map { setIndex, set in
                let isDone = set.status == .done
                return ExerciseResultSet(
                    number: setIndex + 1,
                    weight: unit.weightText(isDone ? set.weightKg ?? 0 : set.targetWeightKg),
                    reps: isDone ? Strings.format("workout_details_reps", set.reps ?? 0) : Strings.text("workout_details_set_skipped"),
                    isDone: isDone
                )
            }
        )
    }

    /// "+7m" / "−4%" / "0m": [magnitude] with the sign of [value].
    private static func signed(_ value: Int, _ magnitude: String) -> String {
        Strings.format(value > 0 ? "workout_details_plus" : value < 0 ? "workout_details_minus" : "workout_details_zero", magnitude)
    }

    /// "1h 12m" / "45m".
    private static func durationText(_ minutes: Int) -> String {
        minutes < 60
            ? Strings.format("workout_details_minutes", minutes)
            : Strings.format("workout_details_hours_minutes", minutes / 60, minutes % 60)
    }
}

private extension Workout {
    /// Whole minutes from start to finish.
    var minutes: Int { Int((finishedAt ?? startedAt).timeIntervalSince(startedAt) / 60) }
}

import Foundation

/// Running and finished workouts, stored in SwiftData (synced to Firestore from part 6). A running
/// workout belongs to a person, not the device: everyone can have one at the same time, and whoever
/// has the person selected continues it. Unless a method takes a user, it works on the selected
/// person's running workout.
///
/// Every change is a read-modify-write of the active workout. The methods are synchronous on the main
/// actor, so quick taps can't overwrite each other (Android needs a mutex for this).
final class WorkoutRepository {
    static let defaultWeightKg = 20.0
    static let defaultReps = 10
    static let freeWorkoutIcon = ItemIcon.activity

    private let local: WorkoutLocalDataSource
    private let userRepository: UserRepository
    private let trainingRepository: TrainingRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date

    init(
        local: WorkoutLocalDataSource,
        userRepository: UserRepository,
        trainingRepository: TrainingRepository,
        settingsRepository: SettingsRepository,
        now: @escaping () -> Date
    ) {
        self.local = local
        self.userRepository = userRepository
        self.trainingRepository = trainingRepository
        self.settingsRepository = settingsRepository
        // Whole milliseconds, as stored, so a saved workout equals the one that was built.
        self.now = { Date(epochMillis: now().epochMillis) }
    }

    // MARK: Reading

    /// The selected person's running workout, or nil; a person has at most one.
    func observeActiveWorkout() -> AsyncStream<Workout?> {
        userRepository.observeSelectedUserId().flatMapLatest { [local] in local.observeActiveWorkout(userId: $0) }
    }

    func observeActiveWorkout(userId: String) -> AsyncStream<Workout?> {
        local.observeActiveWorkout(userId: userId)
    }

    /// The selected person's running workout right now.
    func activeWorkout() -> Workout? {
        try? local.activeWorkout(userId: userRepository.selectedUserId)
    }

    func activeWorkout(userId: String) throws(DataError) -> Workout? {
        try local.activeWorkout(userId: userId)
    }

    /// Newest first.
    func observeFinishedWorkouts(userId: String) -> AsyncStream<[Workout]> {
        local.observeFinishedWorkouts(userId: userId)
    }

    /// One workout of any person, running or finished; nil when it doesn't exist (any more).
    func observeWorkout(id: String) -> AsyncStream<Workout?> {
        local.observeWorkout(id: id)
    }

    /// The completed sets of [exerciseId] in the most recent finished workout that has any.
    func lastHistory(userId: String, exerciseId: String) -> ExerciseHistory? {
        try? local.lastHistory(userId: userId, exerciseId: exerciseId)
    }

    // MARK: Starting

    /// Starts [training] for its owner, or returns their running workout when it's the same training.
    /// A person runs one workout at a time, so this fails while they have another workout running; a
    /// free workout that wasn't started yet is replaced.
    @discardableResult
    func startWorkout(_ training: Training) throws(StartWorkoutError) -> Workout {
        do {
            var current = try local.activeWorkout(userId: training.userId)
            // A free workout nobody started yet is just thrown away.
            if let unstarted = current, !unstarted.isClockStarted {
                try local.delete(id: unstarted.id)
                current = nil
            }
            if let current {
                guard current.trainingId == training.id else { throw StartWorkoutError.anotherWorkoutActive }
                return current
            }
            let workout = Workout(
                id: UUID().uuidString.lowercased(),
                userId: training.userId,
                trainingId: training.id,
                trainingName: training.name,
                trainingIcon: training.icon,
                startedAt: now(),
                exercises: training.exercises.map { entry in
                    let history = lastHistory(userId: training.userId, exerciseId: entry.exercise.id)?.sets ?? []
                    return WorkoutExercise(
                        exercise: entry.exercise,
                        restSeconds: entry.restSeconds,
                        sets: (0..<entry.sets).map { index in
                            let last = history.indices.contains(index) ? history[index] : history.last
                            return WorkoutSet(
                                targetWeightKg: last?.weightKg ?? Self.defaultWeightKg,
                                targetReps: last?.reps ?? Self.defaultReps
                            )
                        }
                    )
                }
            )
            try local.save(workout)
            return workout
        } catch let error as StartWorkoutError {
            throw error
        } catch {
            throw .storage
        }
    }

    /// Opens a free workout for the selected person: no training, no exercises yet; they're added as
    /// the person goes. Its clock waits for "Start workout". Returns their running workout instead
    /// when it's a free one already.
    @discardableResult
    func startFreeWorkout() throws(StartWorkoutError) -> Workout {
        let userId = userRepository.selectedUserId
        let current: Workout?
        do { current = try local.activeWorkout(userId: userId) } catch { throw .storage }
        if let current {
            guard current.isFree else { throw .anotherWorkoutActive }
            return current
        }
        let workout = Workout(
            id: UUID().uuidString.lowercased(),
            userId: userId,
            trainingId: nil,
            trainingName: freeWorkoutName(startedAt: now()),
            trainingIcon: Self.freeWorkoutIcon,
            // The clock starts with "Start workout" (see startFreeWorkoutClock).
            startedAt: Workout.notStarted,
            exercises: []
        )
        do { try local.save(workout) } catch { throw .storage }
        return workout
    }

    /// "Start workout" in a free workout: its clock starts now, and so can its exercises.
    func startFreeWorkoutClock() throws(DataError) {
        try updateActive { workout in
            if !workout.isClockStarted { workout.startedAt = now() }
        }
    }

    // MARK: Free workouts

    /// Adds [exercise] to the running free workout, with as many sets as last time (prefilled with
    /// those results), or one set; the rest between sets is the default rest from Settings.
    /// Returns its index, or nil when the workout isn't free (a training's exercises are fixed).
    @discardableResult
    func addExercise(_ exercise: Exercise) throws(DataError) -> Int? {
        guard let workout = activeWorkout(), workout.isFree else { return nil }
        let history = lastHistory(userId: workout.userId, exerciseId: exercise.id)?.sets ?? []
        let lastSets: [WorkoutSet?] = history.isEmpty ? [nil] : history
        let sets = lastSets.map { last in
            WorkoutSet(targetWeightKg: last?.weightKg ?? Self.defaultWeightKg, targetReps: last?.reps ?? Self.defaultReps)
        }
        let restSeconds = settingsRepository.settings.defaultRestSeconds
        var index: Int?
        try updateActive { active in
            guard active.isFree else { return }
            index = active.exercises.count
            active.exercises.append(WorkoutExercise(exercise: exercise, restSeconds: restSeconds, sets: sets))
        }
        return index
    }

    /// Free workouts: one more set for the exercise at [exerciseIndex], prefilled from its last set.
    /// Only while no other exercise runs, so a finished exercise that gets a set runs again, and its
    /// rest starts before the new set.
    func addSet(exerciseIndex: Int) throws(DataError) {
        try updateActive { workout in
            let running = workout.runningExerciseIndex
            guard workout.isFree, running == nil || running == exerciseIndex, workout.exercises.indices.contains(exerciseIndex) else { return }
            let exercise = workout.exercises[exerciseIndex]
            // Every set was finished: the new one comes after a rest, as if the last set had just been saved.
            if exercise.pendingCount == 0, !exercise.sets.isEmpty, exercise.restSeconds > 0 {
                workout.rest = rest(seconds: exercise.restSeconds, exerciseIndex: exerciseIndex, setIndex: exercise.sets.count - 1)
            }
            let last = exercise.sets.last
            workout.exercises[exerciseIndex].isSkipped = false
            workout.exercises[exerciseIndex].sets.append(WorkoutSet(
                targetWeightKg: last?.weightKg ?? last?.targetWeightKg ?? Self.defaultWeightKg,
                targetReps: last?.reps ?? last?.targetReps ?? Self.defaultReps
            ))
        }
    }

    /// Free workouts: removes the exercise at [exerciseIndex] with its sets. Its rest ends; the rest of
    /// a later exercise follows it to its new index.
    func removeExercise(exerciseIndex: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.isFree, workout.exercises.indices.contains(exerciseIndex) else { return }
            workout.removeExercise(at: exerciseIndex)
        }
    }

    /// Makes the running training workout a free one, so exercises and sets can be added. The
    /// training itself doesn't change; the workout keeps what was logged but is renamed like any free
    /// workout, and it's no longer compared with that training's other workouts.
    func switchToFreeWorkout() throws(DataError) {
        try updateActive { workout in
            guard !workout.isFree else { return }
            workout.trainingId = nil
            workout.trainingName = freeWorkoutName(startedAt: workout.startedAt)
        }
    }

    /// "Free workout · Oct 28" (the day it started), so free workouts can be told apart in history; it
    /// can be renamed when finishing.
    func freeWorkoutName(startedAt: Date) -> String {
        Strings.format("free_workout_dated", startedAt.formatted(.dateTime.month(.abbreviated).day()))
    }

    /// Free workouts: removes a set (done, skipped or still to do). A rest that followed it ends, and so
    /// does the exercise's rest once no set is left to do; otherwise a rest after a later set keeps
    /// pointing at that set. Deleting the last set removes the exercise.
    func deleteSet(exerciseIndex: Int, setIndex: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.isFree, workout.exercises.indices.contains(exerciseIndex) else { return }
            let exercise = workout.exercises[exerciseIndex]
            guard exercise.sets.indices.contains(setIndex) else { return }
            if exercise.sets.count == 1 {
                workout.removeExercise(at: exerciseIndex)
                return
            }
            var sets = exercise.sets
            sets.remove(at: setIndex)
            if let rest = workout.rest, rest.savedExerciseIndex == exerciseIndex {
                if !sets.contains(where: { $0.status == .pending }) || rest.savedSetIndex == setIndex {
                    // No set of this exercise is left to do, or the rest followed the deleted set.
                    workout.rest = nil
                } else if rest.savedSetIndex > setIndex {
                    workout.rest?.savedSetIndex -= 1
                }
            }
            workout.exercises[exerciseIndex].sets = sets
        }
    }

    // MARK: Exercises

    /// Starts the exercise at [exerciseIndex] (a skipped one too). Only one exercise runs at a time,
    /// so nothing changes while another one is still running.
    func startExercise(exerciseIndex: Int) throws(DataError) {
        try updateActive { $0 = start($0, exerciseIndex: exerciseIndex) }
    }

    /// Starts the exercise at [exerciseIndex] in place of the running one, which is set aside as skipped
    /// (its open sets stay pending, so it can be continued later); its rest ends.
    func changeExercise(exerciseIndex: Int) throws(DataError) {
        try updateActive { workout in
            if let running = workout.runningExerciseIndex, running != exerciseIndex {
                workout.exercises[running].isSkipped = true
                workout.rest = nil
            }
            workout = start(workout, exerciseIndex: exerciseIndex)
        }
    }

    private func start(_ workout: Workout, exerciseIndex: Int) -> Workout {
        let running = workout.runningExerciseIndex
        // A free workout's exercises wait for "Start workout".
        guard workout.isClockStarted, running == nil || running == exerciseIndex, workout.exercises.indices.contains(exerciseIndex) else { return workout }
        let exercise = workout.exercises[exerciseIndex]
        guard exercise.pendingCount > 0 else { return workout }
        var updated = workout
        let now = now()
        // Starting it the first time begins with its rest, to get ready for the first set; continuing doesn't.
        if exercise.startedAt == nil, exercise.restSeconds > 0 {
            updated.rest = RestTimer(
                endsAt: now.addingTimeInterval(TimeInterval(exercise.restSeconds)),
                durationSeconds: exercise.restSeconds,
                savedExerciseIndex: exerciseIndex,
                savedSetIndex: RestTimer.beforeFirstSet
            )
        }
        // A new start time also moves it behind the finished exercises in the list (see Workout.displayOrder).
        updated.exercises[exerciseIndex].startedAt = exercise.isRunning ? exercise.startedAt : now
        updated.exercises[exerciseIndex].isSkipped = false
        return updated
    }

    // MARK: Sets

    /// Logs a set. Later pending sets without a previous result follow the new numbers,
    /// so a fresh exercise only needs to be typed in once.
    func completeSet(exerciseIndex: Int, setIndex: Int, weightKg: Double, reps: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.exercises.indices.contains(exerciseIndex) else { return }
            let hasHistory = lastHistory(userId: workout.userId, exerciseId: workout.exercises[exerciseIndex].exercise.id) != nil
            // The rest belonged to the previous set; the next one, if any, starts after this.
            workout.rest = nil
            workout.exercises[exerciseIndex].sets = workout.exercises[exerciseIndex].sets.enumerated().map { index, set in
                var set = set
                if index == setIndex {
                    set.status = .done
                    set.weightKg = weightKg
                    set.reps = reps
                } else if index > setIndex, set.status == .pending, !hasHistory {
                    set.targetWeightKg = weightKg
                    set.targetReps = reps
                }
                return set
            }
        }
    }

    /// Save in Log Set: logs the current set [setIndex] of the running exercise and starts the rest that
    /// follows it, if any. A rest that kept running while the set was logged stops. Does nothing when
    /// that set isn't the one due any more.
    func logSet(exerciseIndex: Int, setIndex: Int, weightKg: Double, reps: Int) throws(DataError) {
        guard let workout = activeWorkout(), workout.exercises.indices.contains(exerciseIndex) else { return }
        let exercise = workout.exercises[exerciseIndex]
        guard exercise.currentSetIndex == setIndex else { return }
        let startsRest = workout.restFollows(exerciseIndex: exerciseIndex, setIndex: setIndex)
        try completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weightKg: weightKg, reps: reps)
        if startsRest { try startRest(seconds: exercise.restSeconds, exerciseIndex: exerciseIndex, setIndex: setIndex) }
    }

    /// Changes what was logged for a completed set; the rest and the following sets' targets stay as they are.
    func editSet(exerciseIndex: Int, setIndex: Int, weightKg: Double, reps: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.exercises.indices.contains(exerciseIndex),
                  workout.exercises[exerciseIndex].sets.indices.contains(setIndex),
                  workout.exercises[exerciseIndex].sets[setIndex].status == .done else { return }
            workout.exercises[exerciseIndex].sets[setIndex].weightKg = weightKg
            workout.exercises[exerciseIndex].sets[setIndex].reps = reps
        }
    }

    /// Skips a set; a rest still showing for the previous set ends with it. When another set of the
    /// exercise follows, its rest starts, as after a done set.
    func skipSet(exerciseIndex: Int, setIndex: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.exercises.indices.contains(exerciseIndex), workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
            let exercise = workout.exercises[exerciseIndex]
            workout.rest = workout.restFollows(exerciseIndex: exerciseIndex, setIndex: setIndex)
                ? rest(seconds: exercise.restSeconds, exerciseIndex: exerciseIndex, setIndex: setIndex)
                : nil
            workout.exercises[exerciseIndex].sets[setIndex].status = .skipped
        }
    }

    /// The skipped set is due again; the rest the skip started ends.
    func undoSkipSet(exerciseIndex: Int, setIndex: Int) throws(DataError) {
        try updateActive { workout in
            guard workout.exercises.indices.contains(exerciseIndex), workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
            if let rest = workout.rest, rest.savedExerciseIndex == exerciseIndex, rest.savedSetIndex == setIndex { workout.rest = nil }
            workout.exercises[exerciseIndex].sets[setIndex].status = .pending
        }
    }

    /// Tries a skipped set again: it's pending, and so the current set, once more. An exercise that was
    /// finished or skipped is running again, unless another exercise is running.
    /// Its rest starts too (when the exercise has one), to get ready for the set.
    func retrySet(exerciseIndex: Int, setIndex: Int) throws(DataError) {
        try updateActive { workout in
            let running = workout.runningExerciseIndex
            guard running == nil || running == exerciseIndex,
                  workout.exercises.indices.contains(exerciseIndex),
                  workout.exercises[exerciseIndex].sets.indices.contains(setIndex),
                  workout.exercises[exerciseIndex].sets[setIndex].status == .skipped else { return }
            let exercise = workout.exercises[exerciseIndex]
            if exercise.restSeconds > 0 {
                workout.rest = rest(
                    seconds: exercise.restSeconds,
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex == 0 ? RestTimer.beforeFirstSet : setIndex - 1
                )
            }
            workout.exercises[exerciseIndex].isSkipped = false
            workout.exercises[exerciseIndex].startedAt = exercise.isRunning ? exercise.startedAt : now()
            workout.exercises[exerciseIndex].sets[setIndex].status = .pending
        }
    }

    // MARK: Rest

    func startRest(seconds: Int, exerciseIndex: Int, setIndex: Int) throws(DataError) {
        try updateActive { $0.rest = rest(seconds: seconds, exerciseIndex: exerciseIndex, setIndex: setIndex) }
    }

    /// Adds [deltaSeconds] (negative to shorten) to the rest, keeping at least 0 s left; works while
    /// paused too. Once the rest is over, adding time starts a new countdown of [deltaSeconds] from now,
    /// and so does adding time while an exercise runs with no rest at all.
    func adjustRest(deltaSeconds: Int) throws(DataError) {
        try updateActive { workout in
            let now = now()
            guard let rest = workout.rest else {
                guard deltaSeconds > 0, let exerciseIndex = workout.runningExerciseIndex,
                      let setIndex = workout.exercises[exerciseIndex].currentSetIndex else { return }
                workout.rest = self.rest(
                    seconds: deltaSeconds,
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex == 0 ? RestTimer.beforeFirstSet : setIndex - 1
                )
                return
            }
            if rest.pausedAt == nil, rest.isOver(now: now) {
                guard deltaSeconds > 0 else { return }
                workout.rest?.endsAt = now.addingTimeInterval(TimeInterval(deltaSeconds))
                workout.rest?.durationSeconds = deltaSeconds
                return
            }
            workout.rest?.endsAt = max(rest.pausedAt ?? now, rest.endsAt.addingTimeInterval(TimeInterval(deltaSeconds)))
            workout.rest?.durationSeconds = max(1, rest.durationSeconds + deltaSeconds)
        }
    }

    func endRest() throws(DataError) {
        try updateActive { $0.rest = nil }
    }

    /// Freezes the countdown of a rest that isn't over yet.
    func pauseRest() throws(DataError) {
        try updateActive { workout in
            let now = now()
            guard let rest = workout.rest, !rest.isPaused, !rest.isOver(now: now) else { return }
            workout.rest?.pausedAt = now
        }
    }

    /// Continues a paused rest with the time it had left.
    func resumeRest() throws(DataError) {
        try updateActive { workout in
            guard let rest = workout.rest, let pausedAt = rest.pausedAt else { return }
            workout.rest?.endsAt = rest.endsAt.addingTimeInterval(now().timeIntervalSince(pausedAt))
            workout.rest?.pausedAt = nil
        }
    }

    /// "Skip set" on the Live Activity: skips the current set of the running exercise.
    func skipCurrentSet() throws(DataError) {
        try endRest()
        guard let workout = activeWorkout(), let exerciseIndex = workout.runningExerciseIndex,
              let setIndex = workout.exercises[exerciseIndex].currentSetIndex else { return }
        try skipSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }

    private func rest(seconds: Int, exerciseIndex: Int, setIndex: Int) -> RestTimer {
        RestTimer(
            endsAt: now().addingTimeInterval(TimeInterval(seconds)),
            durationSeconds: seconds,
            savedExerciseIndex: exerciseIndex,
            savedSetIndex: setIndex
        )
    }

    // MARK: Finishing

    /// Finishes the active workout; pending sets are stored as skipped. A free workout can get a
    /// [name], and with [saveAsTraining] its exercises become a new training it's then linked to.
    /// A free workout without a single done set is dropped instead: there's nothing to keep.
    func finishWorkout(name: String? = nil, saveAsTraining: Bool = false) throws(DataError) {
        guard let active = activeWorkout() else { return }
        if active.isFree, active.doneSetCount == 0 {
            try local.delete(id: active.id)
            return
        }
        try updateActive { workout in
            let exercises = workout.exercises
                // Exercises whose sets were all deleted from a free workout.
                .filter { !$0.sets.isEmpty }
                .map { exercise in
                    var exercise = exercise
                    exercise.sets = exercise.sets.map { set in
                        var set = set
                        if set.status == .pending { set.status = .skipped }
                        return set
                    }
                    return exercise
                }
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let newName = workout.isFree && !trimmed.isEmpty ? trimmed : workout.trainingName
            if workout.isFree, saveAsTraining, let trainingId = self.saveAsTraining(workout, name: newName) {
                workout.trainingId = trainingId
            }
            workout.trainingName = newName
            // A workout with every set done lasted until its last set, not until Finish was tapped.
            workout.finishedAt = workout.setsDoneAt ?? now()
            workout.rest = nil
            workout.exercises = exercises
        }
    }

    /// A training with the exercises that got at least one done set, as many sets as were done; its id,
    /// or nil when it couldn't be saved.
    private func saveAsTraining(_ workout: Workout, name: String) -> String? {
        let exercises = workout.exercises.filter { $0.doneCount > 0 }.map {
            TrainingExercise(exercise: $0.exercise, sets: $0.doneCount, restSeconds: $0.restSeconds)
        }
        guard !exercises.isEmpty else { return nil }
        let training = Training(
            id: UUID().uuidString.lowercased(),
            userId: workout.userId,
            name: name,
            icon: workout.trainingIcon,
            exercises: exercises
        )
        do { try trainingRepository.saveTraining(training) } catch { return nil }
        return training.id
    }

    /// The workout as stored (with the training name it was saved with), running or finished.
    func storedWorkout(id: String) throws(DataError) -> Workout? {
        try local.storedWorkout(id: id)
    }

    /// Replaces the results of a finished workout with [exercises] (Edit workout). The rest of the
    /// workout stays as stored, so its training name isn't swapped for the current one. Does nothing
    /// when it doesn't exist (any more) or is still running.
    func updateFinishedWorkout(id: String, exercises: [WorkoutExercise]) throws(DataError) {
        guard var stored = try local.storedWorkout(id: id), stored.finishedAt != nil else { return }
        stored.exercises = exercises
        try local.save(stored)
    }

        /// Removes a workout from history (and statistics), also on the person's other devices.
    func deleteWorkout(id: String) throws(DataError) {
        try local.delete(id: id)
    }

    // MARK: Helpers

    /// Applies [transform] to the selected person's active workout and saves the result; does nothing
    /// when no workout is active or nothing changed.
    private func updateActive(_ transform: (inout Workout) -> Void) throws(DataError) {
        guard let workout = try local.activeWorkout(userId: userRepository.selectedUserId) else { return }
        var updated = workout
        transform(&updated)
        updated = withSetsDoneAt(updated)
        if updated != workout { try local.save(updated) }
    }

    /// Stops the workout clock when the last set is done or skipped, and restarts it if a set opens again.
    private func withSetsDoneAt(_ workout: Workout) -> Workout {
        guard workout.finishedAt == nil else { return workout }
        var updated = workout
        let allDone = !workout.exercises.isEmpty && !workout.exercises.contains { $0.isOpen }
        if allDone, workout.setsDoneAt == nil {
            updated.setsDoneAt = now()
        } else if !allDone, workout.setsDoneAt != nil {
            updated.setsDoneAt = nil
        }
        return updated
    }
}

/// Why a workout couldn't start.
nonisolated enum StartWorkoutError: Error, Equatable {
    /// Only one workout runs at a time.
    case anotherWorkoutActive
    case storage
}

private extension Workout {
    /// Takes out the exercise at [index]; its rest ends, a later exercise's rest follows it to its new index.
    mutating func removeExercise(at index: Int) {
        if let rest {
            if rest.savedExerciseIndex == index {
                self.rest = nil
            } else if rest.savedExerciseIndex > index {
                self.rest?.savedExerciseIndex -= 1
            }
        }
        exercises.remove(at: index)
    }
}

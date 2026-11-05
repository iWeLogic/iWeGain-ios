import Foundation
import Testing
@testable import iWeGain

/// A clock the tests move by hand.
@MainActor
final class TestClock {
    var now = Date(epochMillis: 1_800_000_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

/// Starting, logging, resting and finishing workouts (the rules ported from Android's WorkoutRepository).
@MainActor
struct WorkoutFlowTests {
    private let clock = TestClock()
    private let container: AppContainer
    private var repository: WorkoutRepository { container.workoutRepository }
    private let bench = BuiltInExercises.exercise(id: "bench_press")!
    private let squat = BuiltInExercises.exercise(id: "back_squat")!

    init() {
        let clock = clock
        container = AppContainer.inMemory(now: { clock.now })
    }

    private func training(id: String = "t1", sets: Int = 3, rest: Int = 90) throws -> Training {
        let training = Training(id: id, userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: sets, restSeconds: rest),
            TrainingExercise(exercise: squat, sets: 2, restSeconds: 0),
        ])
        try container.trainingRepository.saveTraining(training)
        return training
    }

    private var active: Workout { repository.activeWorkout()! }

    @Test func startingATrainingPrefillsDefaultsAndReturnsTheSameWorkoutAgain() throws {
        let training = try training()
        let workout = try repository.startWorkout(training)

        #expect(workout.startedAt == clock.now)
        #expect(workout.exercises.map(\.sets.count) == [3, 2])
        #expect(workout.exercises[0].sets.allSatisfy { $0.targetWeightKg == 20 && $0.targetReps == 10 })
        #expect(try repository.startWorkout(training).id == workout.id)
    }

    @Test func anotherTrainingCantStartWhileOneRuns() throws {
        try repository.startWorkout(try training())
        #expect(throws: StartWorkoutError.anotherWorkoutActive) { try repository.startWorkout(try training(id: "t2")) }
    }

    @Test func anUnstartedFreeWorkoutIsReplacedByATraining() throws {
        let free = try repository.startFreeWorkout()
        #expect(!free.isClockStarted)
        let workout = try repository.startWorkout(try training())
        #expect(workout.id != free.id)
        #expect(active.trainingId == "t1")
    }

    @Test func startingAnExerciseBeginsWithItsRest() throws {
        try repository.startWorkout(try training())
        try repository.startExercise(exerciseIndex: 0)

        #expect(active.runningExerciseIndex == 0)
        #expect(active.rest?.savedSetIndex == RestTimer.beforeFirstSet)
        #expect(active.rest?.endsAt == clock.now.addingTimeInterval(90))
        // Only one exercise runs at a time.
        try repository.startExercise(exerciseIndex: 1)
        #expect(active.exercises[1].startedAt == nil)
    }

    @Test func loggingASetStartsTheRestAndFillsLaterTargets() throws {
        try repository.startWorkout(try training())
        try repository.startExercise(exerciseIndex: 0)
        clock.advance(30)
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 60, reps: 8)

        let exercise = active.exercises[0]
        #expect(exercise.sets[0].status == .done)
        #expect(exercise.sets[1].targetWeightKg == 60 && exercise.sets[1].targetReps == 8)
        #expect(active.rest?.savedSetIndex == 0)
        #expect(active.rest?.endsAt == clock.now.addingTimeInterval(90))
        // The same set again (e.g. a double tap) does nothing.
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 100, reps: 1)
        #expect(active.exercises[0].sets[0].weightKg == 60)
    }

    @Test func theLastSetHasNoRestAndAllSetsDoneStopsTheClock() throws {
        try repository.startWorkout(try training(sets: 1))
        try repository.startExercise(exerciseIndex: 0)
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 60, reps: 8)
        #expect(active.rest == nil)
        #expect(active.runningExerciseIndex == nil)

        try repository.startExercise(exerciseIndex: 1)
        try repository.skipSet(exerciseIndex: 1, setIndex: 0)
        clock.advance(5)
        try repository.skipSet(exerciseIndex: 1, setIndex: 1)
        #expect(active.setsDoneAt == clock.now)

        try repository.undoSkipSet(exerciseIndex: 1, setIndex: 1)
        #expect(active.setsDoneAt == nil)
    }

    @Test func pausingFreezesTheRestAndAdjustingKeepsItNonNegative() throws {
        try repository.startWorkout(try training())
        try repository.startExercise(exerciseIndex: 0)
        clock.advance(30)
        try repository.pauseRest()
        clock.advance(100)
        #expect(active.rest?.remaining(now: clock.now) == 60)

        try repository.resumeRest()
        #expect(active.rest?.remaining(now: clock.now) == 60)
        try repository.adjustRest(deltaSeconds: 15)
        #expect(active.rest?.remaining(now: clock.now) == 75)
        try repository.adjustRest(deltaSeconds: -600)
        #expect(active.rest?.remaining(now: clock.now) == 0)
        // Once it's over, +15 s starts a new 15 s countdown.
        try repository.adjustRest(deltaSeconds: 15)
        #expect(active.rest?.remaining(now: clock.now) == 15)
        #expect(active.rest?.durationSeconds == 15)
    }

    @Test func changingExerciseSetsTheRunningOneAside() throws {
        try repository.startWorkout(try training())
        try repository.startExercise(exerciseIndex: 0)
        try repository.changeExercise(exerciseIndex: 1)

        #expect(active.exercises[0].isSkipped)
        #expect(active.runningExerciseIndex == 1)
        #expect(active.rest == nil)
    }

    @Test func retryingASkippedSetRunsTheExerciseAgain() throws {
        try repository.startWorkout(try training(sets: 1))
        try repository.startExercise(exerciseIndex: 0)
        try repository.skipSet(exerciseIndex: 0, setIndex: 0)
        #expect(active.runningExerciseIndex == nil)

        try repository.retrySet(exerciseIndex: 0, setIndex: 0)
        #expect(active.runningExerciseIndex == 0)
        #expect(active.rest?.savedSetIndex == RestTimer.beforeFirstSet)
    }

    @Test func freeWorkoutGrowsAsYouGo() throws {
        container.settingsRepository.setDefaultRestSeconds(60)
        try repository.startFreeWorkout()
        #expect(try repository.addExercise(bench) == 0)
        #expect(active.exercises[0].restSeconds == 60)
        #expect(active.exercises[0].sets.count == 1)

        // Exercises wait for "Start workout".
        try repository.startExercise(exerciseIndex: 0)
        #expect(active.runningExerciseIndex == nil)
        try repository.startFreeWorkoutClock()
        try repository.startExercise(exerciseIndex: 0)
        try repository.endRest()
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 50, reps: 5)

        // Every set was done: adding one starts a rest before it.
        try repository.addSet(exerciseIndex: 0)
        #expect(active.exercises[0].sets.count == 2)
        #expect(active.exercises[0].sets[1].targetWeightKg == 50)
        #expect(active.rest?.savedSetIndex == 0)

        try repository.deleteSet(exerciseIndex: 0, setIndex: 1)
        #expect(active.exercises[0].sets.count == 1)
        #expect(active.rest == nil)
        try repository.deleteSet(exerciseIndex: 0, setIndex: 0)
        #expect(active.exercises.isEmpty)
    }

    @Test func aTrainingWorkoutCantAddExercisesUntilSwitched() throws {
        try repository.startWorkout(try training())
        #expect(try repository.addExercise(bench) == nil)

        try repository.switchToFreeWorkout()
        #expect(active.isFree)
        #expect(active.trainingName.hasPrefix("Free workout"))
        #expect(try repository.addExercise(bench) == 2)
    }

    @Test func finishingStoresPendingSetsAsSkipped() async throws {
        try repository.startWorkout(try training())
        try repository.startExercise(exerciseIndex: 0)
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 60, reps: 8)
        clock.advance(60)
        try repository.finishWorkout()

        #expect(repository.activeWorkout() == nil)
        let finished = try #require(await repository.observeFinishedWorkouts(userId: User.guestId).first()?.first)
        #expect(finished.finishedAt == clock.now)
        #expect(finished.rest == nil)
        #expect(finished.exercises.flatMap(\.sets).map(\.status) == [.done, .skipped, .skipped, .skipped, .skipped])
        // The next workout starts from these results.
        let next = try repository.startWorkout(try training())
        #expect(next.exercises[0].sets.map(\.targetWeightKg) == [60, 60, 60])
    }

    @Test func anEmptyFreeWorkoutIsDroppedAndANamedOneCanBecomeATraining() async throws {
        try repository.startFreeWorkout()
        try repository.finishWorkout(name: "Nothing")
        #expect(repository.activeWorkout() == nil)
        #expect(await repository.observeFinishedWorkouts(userId: User.guestId).first()?.isEmpty == true)

        try repository.startFreeWorkout()
        try repository.addExercise(bench)
        try repository.startFreeWorkoutClock()
        try repository.startExercise(exerciseIndex: 0)
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 40, reps: 12)
        try repository.finishWorkout(name: "  Morning  ", saveAsTraining: true)

        let finished = try #require(await repository.observeFinishedWorkouts(userId: User.guestId).first()?.first)
        let training = try #require(try container.trainingRepository.allTrainings().first)
        #expect(training.name == "Morning")
        #expect(training.exercises.map(\.sets) == [1])
        #expect(finished.trainingId == training.id)
        #expect(finished.trainingName == "Morning")
    }
}

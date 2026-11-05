import Foundation
import Testing
@testable import iWeGain

/// The phone's side of the watch: the state it publishes and the commands it applies.
@MainActor
struct WorkoutWatchStateTests {
    private let container = AppContainer.inMemory()

    private var workouts: WorkoutRepository { container.workoutRepository }

    /// A running free workout with two sets of bench press, the first one due.
    private func startExercise() throws {
        _ = try workouts.startFreeWorkout()
        try workouts.startFreeWorkoutClock()
        let index = try #require(try workouts.addExercise(BuiltInExercises.exercise(id: "bench_press")!))
        try workouts.addSet(exerciseIndex: index)
        try workouts.startExercise(exerciseIndex: index)
        try workouts.endRest()
    }

    private func state(_ workout: Workout?, unit: WeightUnit = .kg) -> WatchWorkoutState {
        workout.watchState(unit: unit, now: Date())
    }

    @Test func noWorkoutIsInactive() {
        let none: Workout? = nil
        #expect(none.watchState(unit: .lb, now: Date()) == WatchWorkoutState(isActive: false, weightUnit: .lb))
    }

    @Test func anUnstartedFreeWorkoutIsInactive() throws {
        _ = try workouts.startFreeWorkout()
        #expect(!state(workouts.activeWorkout()).isActive)
    }

    @Test func aStartedFreeWorkoutWithoutARunningExerciseAsksToChoose() throws {
        _ = try workouts.startFreeWorkout()
        try workouts.startFreeWorkoutClock()
        let watch = state(workouts.activeWorkout())
        #expect(watch.isActive)
        #expect(watch.setIndex == nil)
        #expect(watch.exerciseIndex == nil)
        #expect(!watch.allSetsDone)
    }

    @Test func theDueSetIsWhatTheWatchShows() throws {
        try startExercise()
        let workout = try #require(workouts.activeWorkout())
        let watch = state(workout, unit: .lb)
        let exerciseIndex = try #require(workout.runningExerciseIndex)
        #expect(watch.exerciseIndex == exerciseIndex)
        #expect(watch.setIndex == 0)
        #expect(watch.setCount == workout.exercises[exerciseIndex].sets.count)
        #expect(watch.exerciseName == workout.exercises[exerciseIndex].exercise.name)
        #expect(watch.restEndsAt == nil)
        #expect(watch.weightUnit == .lb)
    }

    @Test func aSetLoggedOnTheWatchIsSaved() throws {
        try startExercise()
        let before = state(workouts.activeWorkout())
        let exerciseIndex = try #require(before.exerciseIndex)
        workouts.perform(.logSet(exerciseIndex: exerciseIndex, setIndex: 0, weightKg: 62.5, reps: 7))
        let set = try #require(workouts.activeWorkout()?.exercises[exerciseIndex].sets[0])
        #expect(set.status == .done)
        #expect(set.weightKg == 62.5)
        #expect(set.reps == 7)
        #expect(state(workouts.activeWorkout()).setIndex != 0)
    }

    @Test func aSetAlreadyLoggedOnThePhoneIsNotLoggedAgain() throws {
        try startExercise()
        let exerciseIndex = try #require(state(workouts.activeWorkout()).exerciseIndex)
        workouts.perform(.logSet(exerciseIndex: exerciseIndex, setIndex: 0, weightKg: 60, reps: 8))
        workouts.perform(.logSet(exerciseIndex: exerciseIndex, setIndex: 0, weightKg: 99, reps: 1))
        #expect(workouts.activeWorkout()?.exercises[exerciseIndex].sets[0].weightKg == 60)
    }

    @Test func plusFifteenFromTheWatchStartsARest() throws {
        try startExercise()
        workouts.perform(.adjustRest(deltaSeconds: 15))
        let watch = state(workouts.activeWorkout())
        #expect(watch.hasRest)
        #expect(watch.restDurationSeconds == 15)
    }
}

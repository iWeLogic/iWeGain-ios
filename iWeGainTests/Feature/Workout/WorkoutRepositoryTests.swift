import Foundation
import SwiftData
import Testing
@testable import iWeGain

@MainActor
struct WorkoutRepositoryTests {
    private let container = AppContainer.inMemory()
    private var local: WorkoutLocalDataSource { WorkoutLocalDataSource(store: container.store) }
    private var repository: WorkoutRepository { container.workoutRepository }

    /// Without its built-in picture: stored workouts keep only the exercise's own fields, like Android.
    private var bench: Exercise {
        var exercise = BuiltInExercises.exercise(id: "bench_press")!
        exercise.builtInImage = nil
        return exercise
    }

    private func workout(id: String = "w1", trainingId: String? = "t1", startedAt: Int64 = 1_000, finishedAt: Int64? = nil, sets: [WorkoutSet]) -> Workout {
        Workout(
            id: id, userId: "user", trainingId: trainingId, trainingName: "Push day", trainingIcon: .flame,
            startedAt: Date(epochMillis: startedAt), finishedAt: finishedAt.map(Date.init(epochMillis:)),
            exercises: [WorkoutExercise(exercise: bench, restSeconds: 120, sets: sets, startedAt: Date(epochMillis: startedAt))],
            rest: RestTimer(endsAt: Date(epochMillis: 5_000), durationSeconds: 120, savedExerciseIndex: 0, savedSetIndex: 0)
        )
    }

    private func done(_ kg: Double, _ reps: Int) -> WorkoutSet {
        WorkoutSet(status: .done, targetWeightKg: kg, targetReps: reps, weightKg: kg, reps: reps)
    }

    @Test func workoutRoundTripsThroughTheStore() throws {
        let original = workout(sets: [done(100, 5), WorkoutSet(targetWeightKg: 100, targetReps: 5)])
        try local.save(original)

        #expect(try local.storedWorkout(id: "w1") == original)
        #expect(try repository.activeWorkout(userId: "user")?.id == "w1")
        #expect(try repository.activeWorkout(userId: "someone") == nil)
    }

    @Test func freeWorkoutIsStoredWithAnEmptyTrainingId() throws {
        var free = workout(trainingId: nil, sets: [])
        free.startedAt = Workout.notStarted
        try local.save(free)

        let row = try #require(try container.store.context.fetch(FetchDescriptor<WorkoutEntity>()).first)
        #expect(row.trainingId == "")
        #expect(row.startedAt == -1)
        let loaded = try #require(try local.storedWorkout(id: "w1"))
        #expect(loaded.isFree)
        #expect(!loaded.isClockStarted)
    }

    @Test func finishedWorkoutsShowTheTrainingsCurrentName() async throws {
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: "user", name: "Chest & triceps", icon: .zap, exercises: []))
        try local.save(workout(id: "old", startedAt: 1_000, finishedAt: 2_000, sets: [done(90, 5)]))
        try local.save(workout(id: "new", startedAt: 3_000, finishedAt: 4_000, sets: [done(95, 5)]))

        let finished = try #require(await repository.observeFinishedWorkouts(userId: "user").first())
        #expect(finished.map(\.id) == ["new", "old"])
        #expect(finished.allSatisfy { $0.trainingName == "Chest & triceps" && $0.trainingIcon == .zap })
        // Stored copies keep the name they were saved with.
        #expect(try local.storedWorkout(id: "old")?.trainingName == "Push day")
    }

    @Test func lastHistoryIsTheLatestFinishedWorkoutWithDoneSets() throws {
        try local.save(workout(id: "a", startedAt: 1_000, finishedAt: 2_000, sets: [done(90, 5), done(92.5, 4)]))
        try local.save(workout(id: "b", startedAt: 3_000, finishedAt: 4_000, sets: [WorkoutSet(status: .skipped, targetWeightKg: 95, targetReps: 5)]))
        try local.save(workout(id: "running", startedAt: 5_000, sets: [done(200, 1)]))

        let history = try #require(repository.lastHistory(userId: "user", exerciseId: "bench_press"))
        #expect(history.date == Date(epochMillis: 1_000))
        #expect(history.sets.map(\.weightKg) == [90, 92.5])
    }

    @Test func deletingLeavesATombstoneWithoutExercises() throws {
        try local.save(workout(sets: [done(100, 5)]))
        try repository.deleteWorkout(id: "w1")

        #expect(try local.storedWorkout(id: "w1") == nil)
        let row = try #require(try container.store.context.fetch(FetchDescriptor<WorkoutEntity>()).first)
        #expect(row.isDeleted && row.isDirty)
        #expect(try container.store.context.fetchCount(FetchDescriptor<WorkoutSetEntity>()) == 0)
    }

    @Test func modelRules() {
        var running = workout(sets: [done(100, 5), WorkoutSet(targetWeightKg: 100, targetReps: 5)])
        #expect(running.runningExerciseIndex == 0)
        #expect(running.volumeKg == 500)
        #expect(running.restFollows(exerciseIndex: 0, setIndex: 0))
        // The last open set: no rest after it.
        #expect(!running.restFollows(exerciseIndex: 0, setIndex: 1))
        running.exercises[0].sets[1] = done(100, 6)
        #expect(running.runningExerciseIndex == nil)
        #expect(running.exercises[0].bestSet?.reps == 6)
        #expect(running.elapsed(now: Date(epochMillis: 61_000)) == 60)
    }
}

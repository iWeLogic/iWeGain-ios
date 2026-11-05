import Foundation
import Testing
@testable import iWeGain

@MainActor
struct WorkoutDetailsViewModelTests {
    private let container = AppContainer.inMemory()
    private let bench = BuiltInExercises.exercise(id: "bench_press")!
    private let squat = BuiltInExercises.exercise(id: "back_squat")!

    private func done(_ kg: Double, _ reps: Int) -> WorkoutSet {
        WorkoutSet(status: .done, targetWeightKg: kg, targetReps: reps, weightKg: kg, reps: reps)
    }

    private func workout(id: String, trainingId: String? = "t1", startMinute: Int, minutes: Int, exercises: [WorkoutExercise]) -> Workout {
        let start = Date(epochMillis: Int64(startMinute) * 60_000 + 1_000_000_000_000)
        return Workout(
            id: id, userId: User.guestId, trainingId: trainingId, trainingName: "Push Day", trainingIcon: .dumbbell,
            startedAt: start, finishedAt: start.addingTimeInterval(TimeInterval(minutes * 60)), exercises: exercises
        )
    }

    @Test func firstWorkoutOfATraining() {
        let current = workout(id: "w1", startMinute: 0, minutes: 72, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 90, sets: [done(80, 10), WorkoutSet(status: .skipped, targetWeightKg: 85, targetReps: 8)]),
        ])
        let state = WorkoutDetailsViewModel.build(current, finished: [current], unit: .kg)

        #expect(state.title == "Push Day")
        #expect(state.muscles == ["Chest"])
        #expect(state.duration == DetailsStatUi(value: "1h 12m", caption: "First time"))
        #expect(state.volume == DetailsStatUi(value: WeightUnit.kg.volumeText(800), caption: "First time"))
        #expect(state.sets == DetailsStatUi(value: "1", caption: "of 2 planned"))
        #expect(state.records == DetailsStatUi(value: "0 PRs", caption: "No new records"))
        #expect(state.exercises.first?.subtitle == "2 sets · Best 80 kg × 10")
        #expect(state.exercises.first?.sets == [
            ExerciseResultSet(number: 1, weight: "80 kg", reps: "× 10", isDone: true),
            ExerciseResultSet(number: 2, weight: "85 kg", reps: "Skipped", isDone: false),
        ])
    }

    @Test func comparedWithEarlierWorkoutsOfTheSameTraining() {
        let older = workout(id: "a", startMinute: 0, minutes: 60, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 90, sets: [done(80, 10), done(80, 10)]),
            WorkoutExercise(exercise: squat, restSeconds: 90, sets: [done(100, 5)]),
        ])
        let last = workout(id: "b", startMinute: 10_000, minutes: 70, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 90, sets: [done(80, 10), done(80, 10)]),
            WorkoutExercise(exercise: squat, restSeconds: 90, sets: [done(100, 5)]),
        ])
        // Another training's workout counts for records, not for the comparison.
        let otherTraining = workout(id: "c", trainingId: "t2", startMinute: 15_000, minutes: 10, exercises: [
            WorkoutExercise(exercise: squat, restSeconds: 90, sets: [done(120, 1)]),
        ])
        let current = workout(id: "d", startMinute: 20_000, minutes: 61, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 90, sets: [done(85, 10), done(85, 10), done(85, 8)]),
            WorkoutExercise(exercise: squat, restSeconds: 90, sets: [done(110, 5)]),
        ])
        let state = WorkoutDetailsViewModel.build(current, finished: [current, otherTraining, last, older], unit: .kg)

        // Average of 60 and 70 minutes is 65.
        #expect(state.duration == DetailsStatUi(value: "1h 1m", caption: "−4m vs average", isPositive: true))
        // 2,930 kg against 2,100 kg.
        #expect(state.volume == DetailsStatUi(value: WeightUnit.kg.volumeText(2_930), caption: "+40% vs last Push Day", isPositive: true))
        #expect(state.sets == DetailsStatUi(value: "4", caption: "+1 vs last", isPositive: true))
        #expect(state.records == DetailsStatUi(value: "1 PR", caption: bench.name, isPositive: true))
        #expect(state.exercises.map(\.isRecord) == [true, false])
    }

    @Test func freeWorkoutIsntComparedWithAnything() {
        let earlier = workout(id: "a", trainingId: nil, startMinute: 0, minutes: 30, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 0, sets: [done(80, 10)]),
        ])
        let current = workout(id: "b", trainingId: nil, startMinute: 100, minutes: 30, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 0, sets: [done(80, 10)]),
        ])
        let state = WorkoutDetailsViewModel.build(current, finished: [current, earlier], unit: .kg)

        #expect(state.duration?.caption == "First time")
        #expect(state.sets?.caption == "of 1 planned")
    }

    @Test func deletingTheWorkoutCloses() async throws {
        let current = workout(id: "w1", startMinute: 0, minutes: 30, exercises: [
            WorkoutExercise(exercise: bench, restSeconds: 0, sets: [done(80, 10)]),
        ])
        try WorkoutLocalDataSource(store: container.store).save(current)
        let viewModel = container.makeWorkoutDetailsViewModel(workoutId: "w1")
        var events: [WorkoutDetailsEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        for _ in 0..<200 where !viewModel.state.isLoaded { await Task.yield() }
        #expect(viewModel.state.isLoaded)

        viewModel.onAction(.onDeleteTap)
        #expect(viewModel.state.isDeleteConfirmOpen)
        viewModel.onAction(.onDeleteConfirm)
        for _ in 0..<200 where events.isEmpty { await Task.yield() }

        guard case .close = events.last else { Issue.record("Expected close, got \(events)"); return }
        #expect(await container.workoutRepository.observeFinishedWorkouts(userId: User.guestId).first()?.isEmpty == true)
    }
}

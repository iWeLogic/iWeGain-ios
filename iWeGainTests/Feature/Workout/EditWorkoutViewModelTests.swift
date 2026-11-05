import Foundation
import Testing
@testable import iWeGain

@MainActor
struct EditWorkoutViewModelTests {
    private let container = AppContainer.inMemory()
    private let bench = BuiltInExercises.exercise(id: "bench_press")!
    private var local: WorkoutLocalDataSource { WorkoutLocalDataSource(store: container.store) }

    private func done(_ kg: Double, _ reps: Int) -> WorkoutSet {
        WorkoutSet(status: .done, targetWeightKg: kg, targetReps: reps, weightKg: kg, reps: reps)
    }

    private func save(trainingId: String? = "t1", finished: Bool = true, sets: [WorkoutSet]) throws {
        try local.save(Workout(
            id: "w1", userId: User.guestId, trainingId: trainingId, trainingName: "Push Day", trainingIcon: .dumbbell,
            startedAt: Date(epochMillis: 1_000), finishedAt: finished ? Date(epochMillis: 600_000) : nil,
            exercises: [WorkoutExercise(exercise: bench, restSeconds: 90, sets: sets)]
        ))
    }

    private func makeViewModel() -> (EditWorkoutViewModel, () -> [EditWorkoutEvent]) {
        let viewModel = container.makeEditWorkoutViewModel(workoutId: "w1")
        var events: [EditWorkoutEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        return (viewModel, { events })
    }

    private var stored: Workout? { try? container.workoutRepository.storedWorkout(id: "w1") }

    @Test func editingASetAndSaving() throws {
        try save(sets: [done(80, 10), done(80, 8)])
        let (viewModel, events) = makeViewModel()
        let key = try #require(viewModel.state.exercises.first?.key)
        #expect(!viewModel.state.isFree)
        #expect(viewModel.state.exercises.first?.sets.map(\.reps) == ["× 10", "× 8"])

        viewModel.onAction(.onSetTap(exerciseKey: key, setIndex: 1))
        #expect(viewModel.state.logSet?.weight == "80")
        #expect(viewModel.state.logSet?.isDone == true)
        #expect(viewModel.state.logSet?.canDelete == false)
        viewModel.onAction(.onLogSet(.onRepsIncrease))
        viewModel.onAction(.onLogSet(.onSave))
        #expect(viewModel.state.logSet == nil)
        viewModel.onAction(.onSaveTap)

        #expect(stored?.exercises.first?.sets.map(\.reps) == [10, 9])
        guard case .close = events().last else { Issue.record("Expected close, got \(events())"); return }
    }

    @Test func markingASetSkippedKeepsItsValuesAsTheTarget() throws {
        try save(sets: [done(80, 10)])
        let (viewModel, _) = makeViewModel()
        let key = try #require(viewModel.state.exercises.first?.key)

        viewModel.onAction(.onSetTap(exerciseKey: key, setIndex: 0))
        viewModel.onAction(.onLogSet(.onStatusChange(isDone: false)))
        viewModel.onAction(.onLogSet(.onSave))
        #expect(viewModel.state.exercises.first?.sets == [ExerciseResultSet(number: 1, weight: "Skipped", reps: "—", isDone: false)])
        viewModel.onAction(.onSaveTap)

        #expect(stored?.exercises.first?.sets == [WorkoutSet(status: .skipped, targetWeightKg: 80, targetReps: 10)])
    }

    @Test func aTrainingsWorkoutCantAddOrDelete() throws {
        try save(sets: [done(80, 10)])
        let (viewModel, events) = makeViewModel()
        let key = try #require(viewModel.state.exercises.first?.key)

        viewModel.onAction(.onAddSetTap(exerciseKey: key))
        viewModel.onAction(.onDeleteExerciseTap(exerciseKey: key))
        viewModel.onAction(.onAddExerciseTap)

        #expect(viewModel.state.logSet == nil)
        #expect(viewModel.state.deleteExercise == nil)
        #expect(events().isEmpty)
    }

    @Test func freeWorkoutAddsAndDeletesSetsAndExercises() throws {
        try save(trainingId: nil, sets: [done(80, 10)])
        let (viewModel, _) = makeViewModel()
        let key = try #require(viewModel.state.exercises.first?.key)
        #expect(viewModel.state.isFree)

        // A new set starts from the exercise's last one.
        viewModel.onAction(.onAddSetTap(exerciseKey: key))
        #expect(viewModel.state.logSet?.setNumber == 2)
        #expect(viewModel.state.logSet?.reps == "10")
        viewModel.onAction(.onLogSet(.onSave))
        #expect(viewModel.state.exercises.first?.sets.count == 2)

        // A picked exercise opens the sheet for its first set; without history it starts at 20 kg × 10.
        viewModel.onAction(.onExercisePicked(id: "back_squat"))
        #expect(viewModel.state.exercises.count == 2)
        #expect(viewModel.state.logSet?.weight == "20")
        viewModel.onAction(.onLogSet(.onDismiss))

        // Deleting the only set of the bench press removes it... after deleting both sets.
        viewModel.onAction(.onSetTap(exerciseKey: key, setIndex: 1))
        #expect(viewModel.state.logSet?.canDelete == true)
        viewModel.onAction(.onLogSet(.onDelete))
        viewModel.onAction(.onSetTap(exerciseKey: key, setIndex: 0))
        viewModel.onAction(.onLogSet(.onDelete))
        #expect(viewModel.state.exercises.map(\.name) == [BuiltInExercises.exercise(id: "back_squat")!.name])
        // The squat has no sets: nothing is left to save.
        #expect(!viewModel.state.canSave)

        let squatKey = try #require(viewModel.state.exercises.first?.key)
        viewModel.onAction(.onDeleteExerciseTap(exerciseKey: squatKey))
        #expect(viewModel.state.deleteExercise?.setCount == 0)
        viewModel.onAction(.onDeleteExerciseConfirm)
        #expect(viewModel.state.exercises.isEmpty)
    }

    @Test func exercisesWithoutSetsArentSaved() throws {
        try save(trainingId: nil, sets: [done(80, 10)])
        let (viewModel, _) = makeViewModel()
        viewModel.onAction(.onExercisePicked(id: "back_squat"))
        viewModel.onAction(.onLogSet(.onDismiss))
        viewModel.onAction(.onSaveTap)

        #expect(stored?.exercises.map(\.exercise.id) == ["bench_press"])
    }

    @Test func cancelAsksOnlyWhenSomethingChanged() throws {
        try save(sets: [done(80, 10)])
        let (viewModel, events) = makeViewModel()
        let key = try #require(viewModel.state.exercises.first?.key)

        viewModel.onAction(.onSetTap(exerciseKey: key, setIndex: 0))
        viewModel.onAction(.onLogSet(.onRepsDecrease))
        viewModel.onAction(.onLogSet(.onSave))
        viewModel.onAction(.onCancelTap)
        #expect(viewModel.state.isDiscardConfirmOpen)
        #expect(events().isEmpty)
        viewModel.onAction(.onDiscardConfirm)

        guard case .close = events().last else { Issue.record("Expected close, got \(events())"); return }
        #expect(stored?.exercises.first?.sets.first?.reps == 10)
    }

    @Test func deletingTheWorkout() throws {
        try save(sets: [done(80, 10)])
        let (viewModel, events) = makeViewModel()
        viewModel.onAction(.onDeleteWorkoutTap)
        viewModel.onAction(.onDeleteWorkoutConfirm)

        #expect(stored == nil)
        guard case .close = events().last else { Issue.record("Expected close, got \(events())"); return }
    }

    @Test func aRunningWorkoutCantBeEdited() throws {
        try save(finished: false, sets: [done(80, 10)])
        let (viewModel, events) = makeViewModel()
        #expect(!viewModel.state.isLoaded)
        guard case .close = events().last else { Issue.record("Expected close, got \(events())"); return }
        #expect(throws: Never.self) { try container.workoutRepository.updateFinishedWorkout(id: "w1", exercises: []) }
        #expect(stored?.exercises.count == 1)
    }

    @Test func aSkippedSetCanBeSavedWithoutReps() {
        var logSet = LogSetUi(setNumber: 1, exerciseName: "Bench", weightLabel: "", weight: "80", reps: "", isDone: true)
        logSet = logSet.reduce(.onBackspace, weightStep: 0.25)
        #expect(!logSet.canSave)
        logSet = logSet.reduce(.onStatusChange(isDone: false), weightStep: 0.25)
        #expect(logSet.canSave)
    }
}

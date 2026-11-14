import Foundation
import Testing
@testable import iWeGain

@MainActor
struct WorkoutScreensTests {
    private let clock = TestClock()
    private let container: AppContainer
    private let bench = BuiltInExercises.exercise(id: "bench_press")!

    init() {
        let clock = clock
        container = AppContainer.inMemory(now: { clock.now })
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { await Task.yield() }
    }

    @discardableResult
    private func startTraining(sets: Int = 2) throws -> Training {
        let training = Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: sets, restSeconds: 90),
        ])
        try container.trainingRepository.saveTraining(training)
        try container.workoutRepository.startWorkout(training)
        return training
    }

    // MARK: Overview

    @Test func overviewShowsProgressAndExercises() async throws {
        try startTraining()
        let viewModel = container.makeWorkoutViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }

        #expect(viewModel.state.title == "Push Day")
        #expect(viewModel.state.setsProgress == "0 / 2")
        #expect(viewModel.state.setsCaption == "2 left")
        #expect(viewModel.state.volume == "0 kg")
        #expect(viewModel.state.exercises.map(\.subtitle) == ["2 sets · rest 90 s"])
        #expect(viewModel.state.exercises.map(\.status) == [.upcoming])
        #expect(!viewModel.state.isFree)
    }

    @Test func exerciseWithSkippedSetsIsPartlyDoneNotDone() async throws {
        try startTraining(sets: 4)
        let repository = container.workoutRepository
        try repository.startExercise(exerciseIndex: 0)
        for set in 0..<3 { try repository.completeSet(exerciseIndex: 0, setIndex: set, weightKg: 100, reps: 5) }
        try repository.skipSet(exerciseIndex: 0, setIndex: 3)
        let viewModel = container.makeWorkoutViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }

        let exercise = try #require(viewModel.state.exercises.first)
        #expect(exercise.status == .partial)
        #expect(exercise.doneShare == 0.75)
        #expect(exercise.subtitle == "3 of 4 · 1 skipped · best 100 kg × 5")
    }

    @Test func exerciseWithEverySetDoneIsDone() async throws {
        try startTraining(sets: 2)
        let repository = container.workoutRepository
        try repository.startExercise(exerciseIndex: 0)
        for set in 0..<2 { try repository.completeSet(exerciseIndex: 0, setIndex: set, weightKg: 100, reps: 5) }
        let viewModel = container.makeWorkoutViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }

        #expect(viewModel.state.exercises.map(\.status) == [.done])
    }

    @Test func finishingClosesTheWorkout() async throws {
        try startTraining()
        let viewModel = container.makeWorkoutViewModel()
        var events: [WorkoutEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }

        viewModel.onAction(.onFinishTap)
        #expect(viewModel.state.finish?.unfinished.map(\.setsLeft) == ["2 sets left"])
        viewModel.onAction(.onFinishConfirm)
        await waitUntil { events.contains { if case .close = $0 { true } else { false } } }

        #expect(viewModel.state.finish == nil)
        #expect(container.workoutRepository.activeWorkout() == nil)
    }

    @Test func freeWorkoutAddsAPickedExerciseAndStarts() async throws {
        try container.workoutRepository.startFreeWorkout()
        let viewModel = container.makeWorkoutViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }
        #expect(viewModel.state.isFree)
        #expect(!viewModel.state.isStarted)

        viewModel.onAction(.onExercisePicked(id: "bench_press"))
        viewModel.onAction(.onStartWorkoutTap)
        await waitUntil { viewModel.state.isStarted && viewModel.state.exercises.count == 1 }
        #expect(viewModel.state.exercises.first?.name == bench.name)
    }

    @Test func switchingToFreeAsksFirst() async throws {
        try startTraining()
        let viewModel = container.makeWorkoutViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }

        viewModel.onAction(.onSwitchToFreeTap)
        #expect(viewModel.state.isSwitchConfirmOpen)
        viewModel.onAction(.onSwitchToFreeConfirm)
        await waitUntil { viewModel.state.isFree }
        #expect(!viewModel.state.isSwitchConfirmOpen)
    }

    // MARK: Exercise

    @Test func exerciseLogsASetThroughTheSheetAndRests() async throws {
        try startTraining()
        let viewModel = container.makeExerciseViewModel(exerciseIndex: 0)
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }
        #expect(viewModel.state.phase == .ready)

        viewModel.onAction(.onStartExerciseTap)
        await waitUntil { viewModel.state.phase == .running }
        #expect(viewModel.state.rest.isActive)
        #expect(viewModel.state.rest.remaining == "1:30")
        #expect(viewModel.state.sets.map(\.status) == [.current, .upcoming])

        viewModel.onAction(.onCompleteSetTap)
        let logSet = try #require(viewModel.state.logSet)
        #expect(logSet.weight == "20" && logSet.reps == "10")
        #expect(logSet.startsRest)
        viewModel.onAction(.onLogSet(.onFieldTap(.weight)))
        "62.5".forEach { viewModel.onAction(.onLogSet(.onKey($0))) }
        viewModel.onAction(.onLogSet(.onSave))

        #expect(viewModel.state.logSet == nil)
        await waitUntil { viewModel.state.sets.first?.status == .done }
        #expect(viewModel.state.sets.first?.weight == "62.5 kg")
        #expect(viewModel.state.sets.last?.weight == "62.5 kg")
        #expect(viewModel.state.rest.isRunning)
    }

    @Test func savingTheLastSetGoesBackToTheWorkout() async throws {
        try startTraining(sets: 1)
        let viewModel = container.makeExerciseViewModel(exerciseIndex: 0)
        var events: [ExerciseEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }
        viewModel.onAction(.onStartExerciseTap)
        viewModel.onAction(.onCompleteSetTap)
        viewModel.onAction(.onLogSet(.onSave))

        #expect(events.contains { if case .backToWorkout = $0 { true } else { false } })
    }

    @Test func skippingShowsAnUndoPill() async throws {
        try startTraining()
        let viewModel = container.makeExerciseViewModel(exerciseIndex: 0)
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }
        viewModel.onAction(.onStartExerciseTap)
        viewModel.onAction(.onSkipSetTap)
        #expect(viewModel.state.skippedSetNumber == 1)
        await waitUntil { viewModel.state.sets.first?.status == .skipped }

        viewModel.onAction(.onUndoSkipTap)
        #expect(viewModel.state.skippedSetNumber == nil)
        await waitUntil { viewModel.state.sets.first?.status == .current }
    }

    @Test func anotherRunningExerciseAsksToChange() async throws {
        let training = Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: 2, restSeconds: 90),
            TrainingExercise(exercise: bench, sets: 2, restSeconds: 90),
        ])
        try container.trainingRepository.saveTraining(training)
        try container.workoutRepository.startWorkout(training)
        try container.workoutRepository.startExercise(exerciseIndex: 0)
        let viewModel = container.makeExerciseViewModel(exerciseIndex: 1)
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.isLoaded }
        #expect(viewModel.state.blockingExercise?.index == 0)

        viewModel.onAction(.onChangeExerciseTap)
        #expect(viewModel.state.isChangeDialogOpen)
        viewModel.onAction(.onChangeExerciseConfirm)
        await waitUntil { viewModel.state.phase == .running }
        #expect(viewModel.state.blockingExercise == nil)
    }

    @Test func restOverIsSentOnce() async throws {
        try startTraining()
        try container.workoutRepository.startExercise(exerciseIndex: 0)
        let viewModel = container.makeExerciseViewModel(exerciseIndex: 0)
        var restOver = 0
        viewModel.subscribe { if case .restOver = $0 { restOver += 1 } }
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.rest.isRunning }

        clock.advance(91)
        try await Task.sleep(for: .milliseconds(600))
        #expect(viewModel.state.rest.isActive && viewModel.state.rest.isOver)
        #expect(restOver == 1)
    }

    // MARK: Home and Training

    @Test func homeShowsTheBannerOnceTheClockRuns() async throws {
        try container.workoutRepository.startFreeWorkout()
        let viewModel = container.makeHomeViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }
        #expect(viewModel.state.activeWorkout == nil)

        try container.workoutRepository.startFreeWorkoutClock()
        await waitUntil { viewModel.state.activeWorkout != nil }
        #expect(viewModel.state.activeWorkout?.subtitle == "Choose the next exercise")
    }

    @Test func bannerDrainsWithTheRest() throws {
        try startTraining()
        try container.workoutRepository.startExercise(exerciseIndex: 0)
        clock.advance(45)
        let banner = HomeViewModel.banner(try #require(container.workoutRepository.activeWorkout()), now: clock.now)

        #expect(banner.subtitle == "\(bench.name) · Set 1 of 2")
        #expect(banner.progressText == "Rest 0:45")
        #expect(banner.progress == 0.5)
        #expect(banner.elapsed == "0:45")
    }

    @Test func homeFreeWorkoutOpensTheWorkout() {
        let viewModel = container.makeHomeViewModel()
        var events: [HomeEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onFreeWorkoutTap)

        guard case .navigateToWorkout(nil) = events.first else { Issue.record("Unexpected \(events)"); return }
        #expect(container.workoutRepository.activeWorkout()?.isFree == true)
    }

    @Test func trainingStartsAndThenOffersToContinue() async throws {
        let training = Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: 2, restSeconds: 90),
        ])
        try container.trainingRepository.saveTraining(training)
        let viewModel = container.makeTrainingViewModel(trainingId: "t1")
        var events: [TrainingEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)

        viewModel.onAction(.onStartTap)
        guard case .navigateToWorkout(nil) = events.last else { Issue.record("Unexpected \(events)"); return }
        await waitUntil { viewModel.state.isWorkoutActive }
        #expect(viewModel.state.otherActiveWorkout == nil)
    }

    @Test func anotherTrainingsWorkoutBlocksStarting() async throws {
        try startTraining()
        try container.trainingRepository.saveTraining(Training(id: "t2", userId: User.guestId, name: "Leg Day", icon: .mountain, exercises: [
            TrainingExercise(exercise: bench, sets: 1, restSeconds: 0),
        ]))
        let viewModel = container.makeTrainingViewModel(trainingId: "t2")
        viewModel.onAction(.onAppear)
        await waitUntil { viewModel.state.otherActiveWorkout != nil }
        #expect(viewModel.state.otherActiveWorkout == "Push Day")
        #expect(!viewModel.state.isWorkoutActive)
    }
}

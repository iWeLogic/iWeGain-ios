import Foundation
import Testing
@testable import iWeGain

@MainActor
struct TrainingViewModelTests {
    private let container = AppContainer.inMemory()

    private func newTraining() -> TrainingViewModel {
        let viewModel = container.makeTrainingViewModel(trainingId: nil)
        viewModel.onAction(.onAppear)
        return viewModel
    }

    private func savedTraining() throws -> TrainingViewModel {
        let bench = try #require(BuiltInExercises.exercise(id: "bench_press"))
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .flame, exercises: [
            TrainingExercise(exercise: bench, sets: 4, restSeconds: 120),
        ]))
        let viewModel = container.makeTrainingViewModel(trainingId: "t1")
        viewModel.onAction(.onAppear)
        return viewModel
    }

    @Test func savingWithMissingPartsMarksThem() throws {
        let viewModel = newTraining()
        viewModel.onAction(.onSaveTap)

        #expect(viewModel.state.isIconMissing && viewModel.state.isNameMissing && viewModel.state.isExercisesMissing)
        viewModel.onAction(.onNameChange("Legs"))
        #expect(!viewModel.state.isNameMissing)
        #expect(try container.trainingRepository.allTrainings().isEmpty)
    }

    @Test func newTrainingIsSavedForTheSelectedPersonAndCloses() throws {
        container.settingsRepository.setDefaultRestSeconds(75)
        let viewModel = newTraining()
        var events: [TrainingEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onIconSelect(.mountain))
        viewModel.onAction(.onNameChange("  Leg Day "))
        viewModel.onAction(.onExercisePicked(id: "back_squat"))
        viewModel.onAction(.onExercisePicked(id: "leg_press"))
        #expect(viewModel.state.exercises.map(\.rest) == ["75 s", "75 s"])
        #expect(viewModel.state.exercises.map(\.sets) == ["3", "3"])
        viewModel.onAction(.onSetsIncrease(id: viewModel.state.exercises[0].id))
        viewModel.onAction(.onRestIncrease(id: viewModel.state.exercises[1].id))
        viewModel.onAction(.onMoveExercises(from: [1], to: 0))
        viewModel.onAction(.onSaveTap)

        let saved = try #require(try container.trainingRepository.allTrainings().first)
        #expect(saved.name == "Leg Day")
        #expect(saved.userId == User.guestId)
        #expect(saved.icon == .mountain)
        #expect(saved.exercises.map(\.exercise.id) == ["leg_press", "back_squat"])
        #expect(saved.exercises.map(\.sets) == [3, 4])
        #expect(saved.exercises.map(\.restSeconds) == [90, 75])
        guard case .close = events.last else { Issue.record("Expected close, got \(events)"); return }
    }

    @Test func stepsStayWithinLimits() {
        let viewModel = newTraining()
        viewModel.onAction(.onExercisePicked(id: "bench_press"))
        let id = viewModel.state.exercises[0].id
        viewModel.onAction(.onSetsDecrease(id: id))
        viewModel.onAction(.onSetsDecrease(id: id))
        viewModel.onAction(.onSetsDecrease(id: id))
        #expect(viewModel.state.exercises[0].sets == "1")
        #expect(!viewModel.state.exercises[0].canDecreaseSets)
        for _ in 0..<100 { viewModel.onAction(.onRestIncrease(id: id)) }
        #expect(viewModel.state.exercises[0].rest == "10 min")
        #expect(!viewModel.state.exercises[0].canIncreaseRest)
    }

    @Test func existingTrainingOpensReadOnlyAndCancelDiscardsEdits() throws {
        let viewModel = try savedTraining()
        #expect(!viewModel.state.isEditing)
        #expect(viewModel.state.name == "Push Day")
        #expect(viewModel.state.exercises.map(\.rest) == ["2 min"])

        viewModel.onAction(.onEditTap)
        viewModel.onAction(.onNameChange("Changed"))
        viewModel.onAction(.onRemoveExercise(id: viewModel.state.exercises[0].id))
        viewModel.onAction(.onCancelTap)

        #expect(!viewModel.state.isEditing)
        #expect(viewModel.state.name == "Push Day")
        #expect(viewModel.state.exercises.count == 1)
    }

    @Test func editsOfAnExistingTrainingAreSavedInPlace() throws {
        let viewModel = try savedTraining()
        viewModel.onAction(.onEditTap)
        viewModel.onAction(.onNameChange("Chest day"))
        viewModel.onAction(.onSaveTap)

        #expect(!viewModel.state.isEditing)
        #expect(try container.trainingRepository.training(id: "t1")?.name == "Chest day")
        #expect(try container.trainingRepository.allTrainings().count == 1)
    }

    @Test func deletingAsksFirstThenCloses() throws {
        let viewModel = try savedTraining()
        var events: [TrainingEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onEditTap)
        viewModel.onAction(.onNameChange("Unsaved name"))

        viewModel.onAction(.onDeleteTap)
        // The confirmation names the stored training, not the unsaved edit.
        #expect(viewModel.state.deleteConfirmName == "Push Day")
        viewModel.onAction(.onDeleteConfirm)

        #expect(try container.trainingRepository.training(id: "t1") == nil)
        guard case .close = events.last else { Issue.record("Expected close, got \(events)"); return }
    }

    @Test func missingTrainingCloses() {
        let viewModel = container.makeTrainingViewModel(trainingId: "gone")
        var events: [TrainingEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        guard case .close = events.first else { Issue.record("Expected close, got \(events)"); return }
    }
}

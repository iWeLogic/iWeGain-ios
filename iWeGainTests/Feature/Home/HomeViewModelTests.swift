import Foundation
import Testing
@testable import iWeGain

@MainActor
struct HomeViewModelTests {
    private let container = AppContainer.inMemory()

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { await Task.yield() }
    }

    @Test func showsTheSelectedPersonsTrainingsWithCounts() async throws {
        let bench = try #require(BuiltInExercises.exercise(id: "bench_press"))
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: 4, restSeconds: 90),
            TrainingExercise(exercise: bench, sets: 1, restSeconds: 90),
        ]))
        try container.trainingRepository.saveTraining(Training(id: "other", userId: "someone", name: "Theirs", icon: .star, exercises: []))
        let viewModel = container.makeHomeViewModel()

        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }

        #expect(viewModel.state.trainings == [TrainingCardUi(id: "t1", name: "Push Day", icon: "ic_dumbbell", exercises: "2 exercises", sets: "5 sets")])
        #expect(!viewModel.state.isEmpty)
    }

    @Test func emptyStateOnceLoadedWithoutTrainings() async {
        let viewModel = container.makeHomeViewModel()
        #expect(!viewModel.state.isEmpty)
        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }
        #expect(viewModel.state.isEmpty)
    }

    @Test func tapsNavigate() {
        let viewModel = container.makeHomeViewModel()
        var events: [HomeEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onTrainingTap(id: "t1"))
        viewModel.onAction(.onAddTrainingTap)

        guard case .navigateToTraining(let id) = events.first, case .navigateToNewTraining = events.last else {
            Issue.record("Unexpected events \(events)")
            return
        }
        #expect(id == "t1")
    }
}

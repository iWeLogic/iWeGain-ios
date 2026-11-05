import Foundation
import Testing
@testable import iWeGain

@MainActor
struct ExerciseLibraryViewModelTests {
    private let container = AppContainer.inMemory()

    private func loaded() async -> ExerciseLibraryViewModel {
        let viewModel = container.makeExerciseLibraryViewModel()
        viewModel.onAction(.onAppear)
        for _ in 0..<200 where viewModel.state.isLoading { await Task.yield() }
        return viewModel
    }

    @Test func sectionsFollowTheMuscleGroupOrder() async {
        let viewModel = await loaded()
        #expect(viewModel.state.sections.map(\.muscleGroup) == [.chest, .back, .legs, .shoulders, .arms, .core])
        #expect(viewModel.state.sections.reduce(0) { $0 + $1.exercises.count } == 88)
    }

    @Test func searchAndFilterNarrowTheList() async {
        let viewModel = await loaded()
        viewModel.onAction(.onQueryChange("  CURL "))
        #expect(viewModel.state.sections.map(\.muscleGroup) == [.legs, .arms])
        viewModel.onAction(.onMuscleGroupTap(.legs))
        #expect(viewModel.state.sections.flatMap(\.exercises).map(\.name) == ["Leg Curl"])
        viewModel.onAction(.onQueryChange("nothing like this"))
        #expect(viewModel.state.isEmpty)
    }

    @Test func creatingACustomExercisePicksIt() async throws {
        let viewModel = await loaded()
        var events: [ExerciseLibraryEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onCreateCustomTap)
        viewModel.onAction(.onFormSubmit)
        let form = try #require(viewModel.state.form)
        #expect(form.isIconMissing && form.isNameMissing && form.isMuscleGroupMissing && form.isEquipmentMissing)

        viewModel.onAction(.onFormNameChange("Landmine Press"))
        viewModel.onAction(.onFormIconSelect(.flame))
        viewModel.onAction(.onFormMuscleGroupTap(.shoulders))
        viewModel.onAction(.onFormEquipmentTap(.barbell))
        viewModel.onAction(.onFormSubmit)

        #expect(viewModel.state.form == nil)
        guard case .exercisePicked(let id) = events.last else { Issue.record("Expected a pick, got \(events)"); return }
        let created = try #require(container.exerciseRepository.exercise(id: id))
        #expect(created.name == "Landmine Press")
        #expect(created.userId == User.guestId)
        for _ in 0..<200 where !viewModel.state.sections.flatMap(\.exercises).contains(where: { $0.id == id }) { await Task.yield() }
        #expect(viewModel.state.sections.flatMap(\.exercises).first { $0.id == id }?.isCustom == true)
    }

    @Test func editingACustomExerciseSavesItWithoutPicking() async throws {
        let custom = try container.exerciseRepository.createExercise(userId: User.guestId, name: "Sled", muscleGroup: .legs, equipment: .machine, icon: .bike)
        let viewModel = await loaded()
        var events: [ExerciseLibraryEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onEditCustomTap(id: custom.id))
        #expect(viewModel.state.form?.name == "Sled")
        viewModel.onAction(.onFormNameChange("Prowler"))
        viewModel.onAction(.onFormSubmit)

        #expect(viewModel.state.form == nil)
        #expect(events.isEmpty)
        #expect(container.exerciseRepository.exercise(id: custom.id)?.name == "Prowler")
    }

    @Test func builtInExercisesCantBeEdited() async {
        let viewModel = await loaded()
        viewModel.onAction(.onEditCustomTap(id: "bench_press"))
        #expect(viewModel.state.form == nil)
    }
}

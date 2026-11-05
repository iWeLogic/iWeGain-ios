import Foundation
import Testing
@testable import iWeGain

@MainActor
struct ScheduleViewModelTests {
    private let container = AppContainer.inMemory()
    private let day = Day(year: 2026, month: 10, day: 8)

    private func makeViewModel(entryId: String? = nil) -> ScheduleViewModel {
        let viewModel = container.makeScheduleViewModel(date: day, entryId: entryId)
        viewModel.onAction(.onAppear)
        return viewModel
    }

    private func saveTraining(_ id: String) throws {
        try container.trainingRepository.saveTraining(Training(id: id, userId: User.guestId, name: "Pull Day", icon: .zap, exercises: []))
    }

    private func stored() async -> [ScheduledTraining] {
        await container.scheduleRepository.observeScheduled(userId: User.guestId).first() ?? []
    }

    @Test func newEntryNeedsATrainingAndIsSavedForTheSelectedPerson() async throws {
        try saveTraining("pull")
        let viewModel = makeViewModel()
        var events: [ScheduleEvent] = []
        viewModel.subscribe { events.append($0) }
        #expect(viewModel.state.isNew)
        #expect(!viewModel.state.canSave)

        viewModel.onAction(.onSaveTap)
        #expect(await stored().isEmpty)

        viewModel.onAction(.onTrainingPicked(id: "pull"))
        #expect(viewModel.state.training == TrainingChoiceUi(id: "pull", name: "Pull Day", icon: "ic_zap", exercises: "0 exercises"))
        viewModel.onAction(.onRepeatChange(true))
        viewModel.onAction(.onSaveTap)

        let entry = try #require(await stored().first)
        #expect(entry.trainingId == "pull")
        #expect(entry.date == day)
        #expect(entry.startTime == TimeOfDay(hour: 18, minute: 0))
        #expect(entry.endTime == TimeOfDay(hour: 19, minute: 0))
        #expect(entry.repeatsWeekly)
        guard case .close = events.last else { Issue.record("Expected close, got \(events)"); return }
    }

    @Test func movingTheStartKeepsTheLengthAndAnEndBeforeTheStartCantBeSaved() throws {
        try saveTraining("pull")
        let viewModel = makeViewModel()
        viewModel.onAction(.onTrainingPicked(id: "pull"))

        viewModel.onAction(.onStartTimeChange(TimeOfDay(hour: 7, minute: 30)))
        #expect(viewModel.state.endTime == TimeOfDay(hour: 8, minute: 30))

        viewModel.onAction(.onEndTimeChange(TimeOfDay(hour: 7, minute: 0)))
        #expect(!viewModel.state.isTimeValid)
        #expect(!viewModel.state.canSave)
        // An invalid length isn't carried over when the start moves again.
        viewModel.onAction(.onStartTimeChange(TimeOfDay(hour: 6, minute: 0)))
        #expect(viewModel.state.endTime == TimeOfDay(hour: 7, minute: 0))
        #expect(viewModel.state.canSave)
    }

    @Test func editingOneOccurrenceOfASeriesKeepsTheRestOfTheSeries() async throws {
        try saveTraining("pull")
        try saveTraining("legs")
        let series = try container.scheduleRepository.schedule(
            userId: User.guestId, trainingId: "pull", date: day.adding(weeks: -1),
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        )
        let viewModel = makeViewModel(entryId: series.id)
        #expect(!viewModel.state.isLoading)
        #expect(viewModel.state.isPartOfSeries)
        #expect(viewModel.state.training?.id == "pull")

        viewModel.onAction(.onTrainingPicked(id: "legs"))
        viewModel.onAction(.onSaveTap)

        let entries = await stored()
        #expect(entries.count == 2)
        #expect(entries.first { $0.id == series.id }?.skippedDates == [day])
        #expect(entries.first { $0.id != series.id }.map { ($0.trainingId, $0.date, $0.seriesId) } ?? ("", day, nil) == ("legs", day, series.id))
    }

    @Test func removingTheWholeSeries() async throws {
        try saveTraining("pull")
        let series = try container.scheduleRepository.schedule(
            userId: User.guestId, trainingId: "pull", date: day,
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        )
        let viewModel = makeViewModel(entryId: series.id)
        viewModel.onAction(.onApplyToAllChange(true))
        viewModel.onAction(.onRemoveTap)

        #expect(await stored().isEmpty)
    }

    @Test func aMissingEntryCloses() {
        let viewModel = container.makeScheduleViewModel(date: day, entryId: "gone")
        var events: [ScheduleEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        guard case .close = events.last else { Issue.record("Expected close, got \(events)"); return }
    }

    @Test func selectTrainingConfirmsTheSelectedOne() async throws {
        try saveTraining("pull")
        let viewModel = container.makeSelectTrainingViewModel(selectedTrainingId: nil)
        var events: [SelectTrainingEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onAppear)
        for _ in 0..<200 where viewModel.state.isLoading { await Task.yield() }

        viewModel.onAction(.onConfirmTap)
        #expect(events.isEmpty)
        viewModel.onAction(.onOptionTap(id: "pull"))
        #expect(viewModel.state.selected?.name == "Pull Day")
        viewModel.onAction(.onConfirmTap)
        guard case .selected("pull") = events.last else { Issue.record("Expected selected, got \(events)"); return }
    }
}

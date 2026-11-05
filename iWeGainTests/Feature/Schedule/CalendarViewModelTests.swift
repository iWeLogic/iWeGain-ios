import Foundation
import Testing
@testable import iWeGain

@MainActor
struct CalendarViewModelTests {
    /// Tuesday, 29 September 2026, noon.
    private let today = Day(year: 2026, month: 9, day: 29)
    private let container: AppContainer
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // Monday.
        return calendar
    }()

    init() {
        let now = Day(year: 2026, month: 9, day: 29).date(at: TimeOfDay(hour: 12, minute: 0))
        container = AppContainer.inMemory(now: { now })
    }

    private func makeViewModel() -> CalendarViewModel {
        let viewModel = CalendarViewModel(
            userRepository: container.userRepository,
            syncManager: container.syncManager,
            trainingRepository: container.trainingRepository,
            scheduleRepository: container.scheduleRepository,
            workoutRepository: container.workoutRepository,
            now: container.store.now,
            calendar: calendar
        )
        viewModel.onAction(.onAppear)
        return viewModel
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { await Task.yield() }
    }

    private func saveTraining(_ id: String, _ name: String) throws {
        try container.trainingRepository.saveTraining(Training(id: id, userId: User.guestId, name: name, icon: .zap, exercises: []))
    }

    private func saveFinishedWorkout(id: String, trainingId: String, on day: Day, from start: TimeOfDay, minutes: Int) throws {
        let bench = BuiltInExercises.exercise(id: "bench_press")!
        let startedAt = day.date(at: start)
        try WorkoutLocalDataSource(store: container.store).save(Workout(
            id: id, userId: User.guestId, trainingId: trainingId, trainingName: "Push Day", trainingIcon: .dumbbell,
            startedAt: startedAt, finishedAt: startedAt.addingTimeInterval(TimeInterval(minutes * 60)),
            exercises: [WorkoutExercise(exercise: bench, restSeconds: 90, sets: [
                WorkoutSet(status: .done, targetWeightKg: 60, targetReps: 8, weightKg: 60, reps: 8),
                WorkoutSet(status: .skipped, targetWeightKg: 60, targetReps: 8),
            ])]
        ))
    }

    @Test func monthGridStartsOnTheLocalesFirstWeekdayWithTodaySelected() {
        let viewModel = makeViewModel()
        let state = viewModel.state

        #expect(state.weekdayLabels.count == 7)
        #expect(state.weekdayLabels.first == calendar.shortWeekdaySymbols[1])  // Monday.
        // September 2026 starts on a Tuesday: the grid runs from Monday 31 August to Sunday 4 October.
        #expect(state.weeks.count == 5)
        #expect(state.weeks.first?.first?.date == Day(year: 2026, month: 8, day: 31))
        #expect(state.weeks.last?.last?.date == Day(year: 2026, month: 10, day: 4))
        #expect(state.weeks.first?.first?.inMonth == false)
        let selected = state.weeks.flatMap { $0 }.filter(\.isSelected)
        #expect(selected.map(\.date) == [today])
        #expect(selected.first?.isToday == true)
        #expect(state.selectedDate == today)
    }

    @Test func marksFinishedWorkoutsAndPlansAndListsTheSelectedDay() async throws {
        try saveTraining("pull", "Pull Day")
        try saveFinishedWorkout(id: "w1", trainingId: "push", on: today, from: TimeOfDay(hour: 8, minute: 0), minutes: 72)
        let tomorrow = today.adding(days: 1)
        try container.scheduleRepository.schedule(
            userId: User.guestId, trainingId: "pull", date: tomorrow,
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        )
        let viewModel = makeViewModel()
        await waitUntil { !viewModel.state.completed.isEmpty }

        let days = Dictionary(uniqueKeysWithValues: viewModel.state.weeks.flatMap { $0 }.map { ($0.date, $0.mark) })
        #expect(days[today] == .completed)
        #expect(days[tomorrow] == .scheduled)
        #expect(days[today.adding(days: -1)] == DayMark.none)
        #expect(viewModel.state.completed == [CompletedWorkoutUi(
            id: "w1", title: "Push Day", icon: "ic_dumbbell", exercises: "1 exercise", duration: "1 h 12 min", doneSets: "1 set"
        )])
        #expect(viewModel.state.planned.isEmpty)

        viewModel.onAction(.onDayTap(tomorrow))
        let planned = try #require(viewModel.state.planned.first)
        #expect(planned.title == "Pull Day")
        #expect(planned.repeats)
        #expect(!planned.isMissed)
        #expect(planned.time == "\(TimeOfDay(hour: 18, minute: 0).formatted()) – \(TimeOfDay(hour: 19, minute: 0).formatted())")
        #expect(viewModel.state.completed.isEmpty)
    }

    @Test func aFinishedWorkoutStandsInForThatDaysPlanAndPastPlansAreMissed() async throws {
        try saveTraining("pull", "Pull Day")
        let yesterday = today.adding(days: -1)
        let twoDaysAgo = today.adding(days: -2)
        // Planned at the epoch, so the workout finished later can stand in for it.
        try ScheduleLocalDataSource(store: container.store).save(ScheduledTraining(
            id: "s1", userId: User.guestId, trainingId: "pull", date: twoDaysAgo,
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        ))
        try saveFinishedWorkout(id: "w1", trainingId: "push", on: twoDaysAgo, from: TimeOfDay(hour: 7, minute: 0), minutes: 45)
        try container.scheduleRepository.schedule(
            userId: User.guestId, trainingId: "pull", date: yesterday,
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: false
        )
        let viewModel = makeViewModel()
        await waitUntil { !viewModel.state.weeks.flatMap { $0 }.allSatisfy { $0.mark == .none } }

        viewModel.onAction(.onDayTap(twoDaysAgo))
        #expect(viewModel.state.planned.isEmpty)
        #expect(viewModel.state.completed.map(\.id) == ["w1"])
        viewModel.onAction(.onDayTap(yesterday))
        #expect(viewModel.state.planned.map(\.isMissed) == [true])
    }

    @Test func switchingMonthsAndTappingAnotherMonthsDay() throws {
        let viewModel = makeViewModel()
        let september = viewModel.state.monthTitle

        viewModel.onAction(.onNextMonthTap)
        #expect(viewModel.state.monthTitle != september)
        #expect(viewModel.state.weeks.flatMap { $0 }.contains { $0.date == Day(year: 2026, month: 10, day: 31) && $0.inMonth })
        // The selected day stays selected while another month shows.
        #expect(viewModel.state.selectedDate == today)

        viewModel.onAction(.onPreviousMonthTap)
        viewModel.onAction(.onPreviousMonthTap)
        let august = viewModel.state.monthTitle
        viewModel.onAction(.onDayTap(Day(year: 2026, month: 9, day: 2)))
        #expect(viewModel.state.monthTitle == september)
        #expect(viewModel.state.monthTitle != august)
        #expect(viewModel.state.selectedDate == Day(year: 2026, month: 9, day: 2))
    }

    @Test func tapsNavigateWithTheSelectedDay() {
        let viewModel = makeViewModel()
        var events: [CalendarEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onDayTap(today.adding(days: 3)))
        viewModel.onAction(.onScheduleTap)
        viewModel.onAction(.onPlannedTap(entryId: "s1"))
        viewModel.onAction(.onWorkoutTap(id: "w1"))

        guard events.count == 3,
              case .navigateToSchedule(let newDate, nil) = events[0],
              case .navigateToSchedule(let editDate, "s1") = events[1],
              case .navigateToWorkoutDetails("w1") = events[2] else {
            Issue.record("Unexpected events \(events)")
            return
        }
        #expect(newDate == today.adding(days: 3))
        #expect(editDate == today.adding(days: 3))
    }
}

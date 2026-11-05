import Foundation

/// Calendar: a month of finished workouts and planned trainings of the selected person, and the
/// selected day's list, under the person switcher.
final class CalendarViewModel: BaseViewModel<CalendarState, CalendarAction, CalendarEvent> {
    private let userRepository: UserRepository
    private let syncManager: SyncManager
    private let trainingRepository: TrainingRepository
    private let scheduleRepository: ScheduleRepository
    private let workoutRepository: WorkoutRepository
    private let calendar: Calendar
    private let today: Day
    private var isObserving = false

    private var visibleMonth: Day
    private var selectedDate: Day
    /// The latest data of the selected person, rebuilt into the month whenever it or the month changes.
    private var data: (scheduled: [ScheduledTraining], trainings: [String: Training], finished: [Workout])?

    init(
        userRepository: UserRepository,
        syncManager: SyncManager,
        trainingRepository: TrainingRepository,
        scheduleRepository: ScheduleRepository,
        workoutRepository: WorkoutRepository,
        now: () -> Date,
        calendar: Calendar = .current
    ) {
        self.userRepository = userRepository
        self.syncManager = syncManager
        self.trainingRepository = trainingRepository
        self.scheduleRepository = scheduleRepository
        self.workoutRepository = workoutRepository
        self.calendar = calendar
        today = Day(now(), calendar: calendar)
        visibleMonth = today.startOfMonth
        selectedDate = today
        super.init(initialState: CalendarState(selectedDate: today))
        let firstWeekday = Day.firstIsoWeekday(calendar: calendar)
        let symbols = calendar.shortWeekdaySymbols  // Sunday first.
        updateState { state in
            state.weekdayLabels = (0..<7).map { symbols[(firstWeekday + $0) % 7] }
        }
        rebuild()
    }

    override func onAction(_ action: CalendarAction) {
        switch action {
        case .onAppear: observe()
        case .onUserTap(let id): userRepository.selectUser(id)
        case .onCreateProfileTap: sendEvent(.navigateToCreateProfile)
        case .onInviteTap: sendEvent(.navigateToInvite)
        case .onPreviousMonthTap:
            visibleMonth = visibleMonth.adding(months: -1)
            rebuild()
        case .onNextMonthTap:
            visibleMonth = visibleMonth.adding(months: 1)
            rebuild()
        case .onDayTap(let date):
            selectedDate = date
            // Tapping a greyed day of the next/previous month jumps to that month.
            visibleMonth = date.startOfMonth
            rebuild()
        case .onWorkoutTap(let id): sendEvent(.navigateToWorkoutDetails(workoutId: id))
        case .onPlannedTap(let entryId): sendEvent(.navigateToSchedule(date: selectedDate, entryId: entryId))
        case .onScheduleTap: sendEvent(.navigateToSchedule(date: selectedDate, entryId: nil))
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            for await (users, selectedId) in combineLatest(userRepository.observeUsers(), userRepository.observeSelectedUserId()) {
                updateState { $0.users = users.map { $0.toUserUi(isSelected: $0.id == selectedId) } }
            }
        }
        launch { [self] in
            for await status in syncManager.observeStatus() { updateState { $0.isOffline = status == .offline } }
        }
        launch { [self] in
            let userData = userRepository.observeSelectedUserId().flatMapLatest { [scheduleRepository, trainingRepository, workoutRepository] userId in
                combineLatest(
                    scheduleRepository.observeScheduled(userId: userId),
                    trainingRepository.observeTrainings(userId: userId),
                    workoutRepository.observeFinishedWorkouts(userId: userId)
                )
            }
            for await (scheduled, trainings, finished) in userData {
                data = (scheduled, Dictionary(trainings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }), finished)
                rebuild()
            }
        }
    }

    /// Builds everything the month card and the day list show.
    private func rebuild() {
        let month = visibleMonth
        let selected = selectedDate
        let firstWeekday = Day.firstIsoWeekday(calendar: calendar)
        let lastWeekday = (firstWeekday + 5) % 7 + 1
        let gridStart = month.previousOrSame(isoWeekday: firstWeekday)
        let gridEnd = month.adding(days: month.lengthOfMonth - 1).nextOrSame(isoWeekday: lastWeekday)

        let finished = data?.finished ?? []
        let finishedByDate = Dictionary(grouping: finished) { Day($0.startedAt, calendar: calendar) }
        // The selected day can be outside the grid after switching months.
        let scheduled = (data?.scheduled ?? [])
            .occurrences(from: min(gridStart, selected), to: max(gridEnd, selected))
            .withoutReplaced(finishedByDate: finishedByDate)
        let scheduledDates = Set(scheduled.map(\.date))

        let days = (0...(gridEnd.epochDay - gridStart.epochDay)).map { gridStart.adding(days: $0) }
        let weeks = stride(from: 0, to: days.count, by: 7).map { start in
            days[start..<min(start + 7, days.count)].map { date in
                CalendarDayUi(
                    date: date,
                    inMonth: date.startOfMonth == month,
                    isToday: date == today,
                    isSelected: date == selected,
                    mark: finishedByDate[date] != nil ? .completed : (scheduledDates.contains(date) ? .scheduled : .none)
                )
            }
        }
        let trainings = data?.trainings ?? [:]
        let planned = scheduled.filter { $0.date == selected }.compactMap { entry -> PlannedTrainingUi? in
            guard let training = trainings[entry.trainingId] else { return nil }
            return PlannedTrainingUi(
                id: entry.id,
                icon: training.icon.imageName,
                title: training.name,
                time: "\(entry.startTime.formatted(calendar: calendar)) – \(entry.endTime.formatted(calendar: calendar))",
                isMissed: entry.date < today,
                repeats: entry.isPartOfSeries
            )
        }
        let completed = (finishedByDate[selected] ?? []).sorted { $0.startedAt < $1.startedAt }.map { workout in
            CompletedWorkoutUi(
                id: workout.id,
                title: workout.trainingName,
                icon: workout.trainingIcon.imageName,
                exercises: Strings.plural("training_exercise_count", workout.exercises.count),
                duration: Durations.workout(minutes: Int((workout.finishedAt ?? workout.startedAt).timeIntervalSince(workout.startedAt) / 60)),
                doneSets: Strings.plural("training_set_count", workout.doneSetCount)
            )
        }
        updateState { state in
            state.monthTitle = month.monthTitle
            state.weeks = weeks
            state.selectedDate = selected
            state.selectedDateTitle = selected.shortTitle
            state.completed = completed
            state.planned = planned
        }
    }
}

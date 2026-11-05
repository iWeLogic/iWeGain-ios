extension AppContainer {
    var scheduleRepository: ScheduleRepository {
        ScheduleRepository(local: ScheduleLocalDataSource(store: store), now: store.now)
    }
}

extension AppContainer {
    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(
            userRepository: userRepository,
            syncManager: syncManager,
            trainingRepository: trainingRepository,
            scheduleRepository: scheduleRepository,
            workoutRepository: workoutRepository,
            now: store.now
        )
    }

    func makeScheduleViewModel(date: Day, entryId: String?) -> ScheduleViewModel {
        ScheduleViewModel(
            date: date,
            entryId: entryId,
            userRepository: userRepository,
            trainingRepository: trainingRepository,
            scheduleRepository: scheduleRepository
        )
    }

    func makeSelectTrainingViewModel(selectedTrainingId: String?) -> SelectTrainingViewModel {
        SelectTrainingViewModel(selectedTrainingId: selectedTrainingId, userRepository: userRepository, trainingRepository: trainingRepository)
    }
}

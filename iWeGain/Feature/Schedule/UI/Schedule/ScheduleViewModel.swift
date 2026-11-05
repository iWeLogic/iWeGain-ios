import Foundation

/// Schedules a training on [date], or edits the occurrence of [entryId] on that day. For a weekly
/// series "Apply to all repeats" decides whether saving or removing changes only this day or every week.
final class ScheduleViewModel: BaseViewModel<ScheduleState, ScheduleAction, ScheduleEvent> {
    private let date: Day
    private let entryId: String?
    private let userRepository: UserRepository
    private let trainingRepository: TrainingRepository
    private let scheduleRepository: ScheduleRepository
    private var isLoaded = false

    init(
        date: Day,
        entryId: String?,
        userRepository: UserRepository,
        trainingRepository: TrainingRepository,
        scheduleRepository: ScheduleRepository
    ) {
        self.date = date
        self.entryId = entryId
        self.userRepository = userRepository
        self.trainingRepository = trainingRepository
        self.scheduleRepository = scheduleRepository
        super.init(initialState: ScheduleState(
            isLoading: entryId != nil,
            entryId: entryId,
            dateTitle: date.shortTitle,
            weekdayName: date.weekdayName
        ))
    }

    override func onAction(_ action: ScheduleAction) {
        switch action {
        case .onAppear: loadEntry()
        case .onCancelTap: sendEvent(.close)
        case .onSelectTrainingTap: sendEvent(.navigateToSelectTraining(selectedTrainingId: state.training?.id))
        case .onTrainingPicked(let id):
            if let training = try? trainingRepository.training(id: id) { updateState { $0.training = Self.choice(training) } }
        case .onStartTimeChange(let time):
            updateState { state in
                // Keep the same length when the start moves, like a calendar app does.
                let length = state.endTime.secondOfDay - state.startTime.secondOfDay
                if length > 0 { state.endTime = time.adding(seconds: length) }
                state.startTime = time
            }
        case .onEndTimeChange(let time): updateState { $0.endTime = time }
        case .onRepeatChange(let repeats): updateState { $0.repeatsWeekly = repeats }
        case .onApplyToAllChange(let applyToAll): updateState { $0.applyToAll = applyToAll }
        case .onSaveTap: save()
        case .onRemoveTap: remove()
        }
    }

    private func loadEntry() {
        guard let entryId, !isLoaded else { return }
        isLoaded = true
        guard let entry = try? scheduleRepository.entry(id: entryId) else {
            sendEvent(.close)
            return
        }
        let training = try? trainingRepository.training(id: entry.trainingId)
        updateState { state in
            state.training = training.map(Self.choice)
            state.startTime = entry.startTime
            state.endTime = entry.endTime
            state.repeatsWeekly = entry.repeatsWeekly
            state.isPartOfSeries = entry.isPartOfSeries
            state.isLoading = false
        }
    }

    private func save() {
        let form = state
        guard let training = form.training, form.canSave else { return }
        do throws(DataError) {
            if let entryId {
                try scheduleRepository.edit(
                    entryId: entryId, date: date, trainingId: training.id, startTime: form.startTime,
                    endTime: form.endTime, repeatsWeekly: form.repeatsWeekly, applyToAll: form.applyToAll
                )
            } else {
                try scheduleRepository.schedule(
                    userId: userRepository.selectedUserId, trainingId: training.id, date: date,
                    startTime: form.startTime, endTime: form.endTime, repeatsWeekly: form.repeatsWeekly
                )
            }
            sendEvent(.close)
        } catch {
            showError(error)
        }
    }

    private func remove() {
        guard let entryId else { return }
        do throws(DataError) {
            try scheduleRepository.remove(entryId: entryId, date: date, applyToAll: state.applyToAll)
            sendEvent(.close)
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: DataError) {
        if let message = error.message { sendEvent(.showError(message)) }
    }

    private static func choice(_ training: Training) -> TrainingChoiceUi {
        TrainingChoiceUi(id: training.id, name: training.name, icon: training.icon.imageName,
                         exercises: Strings.plural("training_exercise_count", training.exerciseCount))
    }
}

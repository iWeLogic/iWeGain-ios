import Foundation

struct ScheduleState: Equatable {
    /// Editing: the stored entry is being read; a new entry has nothing to load.
    var isLoading = false
    /// The entry being edited; nil when scheduling a new one.
    var entryId: String?
    /// "Thu, Oct 8".
    var dateTitle = ""
    var training: TrainingChoiceUi?
    var startTime = TimeOfDay(hour: 18, minute: 0)
    var endTime = TimeOfDay(hour: 19, minute: 0)
    /// "Repeat every week", for a new entry or a single one being edited.
    var repeatsWeekly = false
    /// Editing an occurrence of a weekly series: shows "Apply to all repeats" instead of the repeat switch.
    var isPartOfSeries = false
    /// Edit or remove every occurrence of the series, not only this one.
    var applyToAll = false
    /// "Thursday", the weekday it repeats on.
    var weekdayName = ""

    var isNew: Bool { entryId == nil }
    /// The end is after the start.
    var isTimeValid: Bool { endTime.secondOfDay - startTime.secondOfDay >= 60 }
    var canSave: Bool { training != nil && isTimeValid }
}

struct TrainingChoiceUi: Equatable {
    let id: String
    let name: String
    let icon: String
    /// "5 exercises".
    let exercises: String
}

enum ScheduleAction {
    case onAppear
    case onCancelTap
    case onSelectTrainingTap
    case onTrainingPicked(id: String)
    case onStartTimeChange(TimeOfDay)
    case onEndTimeChange(TimeOfDay)
    case onRepeatChange(Bool)
    case onApplyToAllChange(Bool)
    case onSaveTap
    case onRemoveTap
}

enum ScheduleEvent: UiEvent {
    case navigateToSelectTraining(selectedTrainingId: String?)
    case close
    case showError(LocalizedStringResource)
}

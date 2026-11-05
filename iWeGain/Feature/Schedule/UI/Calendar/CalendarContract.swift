struct CalendarState: Equatable {
    var users: [UserUi] = []
    /// The server couldn't be reached; shows "Offline" next to the person.
    var isOffline = false
    var monthTitle = ""
    var weekdayLabels: [String] = []
    var weeks: [[CalendarDayUi]] = []
    var selectedDate = Day(epochDay: 0)
    /// "Wed, Sep 30".
    var selectedDateTitle = ""
    /// Workouts finished on [selectedDate].
    var completed: [CompletedWorkoutUi] = []
    /// Trainings planned for [selectedDate], without the ones a finished workout stands in for.
    var planned: [PlannedTrainingUi] = []

    var isDayEmpty: Bool { completed.isEmpty && planned.isEmpty }
}

struct PlannedTrainingUi: Identifiable, Equatable {
    /// The schedule entry; a weekly series shows once per week with the same id.
    let id: String
    let icon: String
    let title: String
    /// "18:00 – 19:00".
    let time: String
    /// Planned for a past day and not done.
    let isMissed: Bool
    /// Part of a weekly series.
    let repeats: Bool
}

struct CompletedWorkoutUi: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    /// "5 exercises".
    let exercises: String
    /// "1 h 12 min".
    let duration: String
    /// "18 sets".
    let doneSets: String
}

enum CalendarAction {
    case onAppear
    case onUserTap(id: String)
    case onCreateProfileTap
    case onInviteTap
    case onPreviousMonthTap
    case onNextMonthTap
    case onDayTap(Day)
    /// A finished workout: opens its result.
    case onWorkoutTap(id: String)
    /// A planned training: opens it for editing.
    case onPlannedTap(entryId: String)
    case onScheduleTap
}

enum CalendarEvent: UiEvent {
    case navigateToCreateProfile
    case navigateToInvite
    case navigateToWorkoutDetails(workoutId: String)
    /// Schedules a training on [date], or edits the occurrence of [entryId] on that day.
    case navigateToSchedule(date: Day, entryId: String?)
}

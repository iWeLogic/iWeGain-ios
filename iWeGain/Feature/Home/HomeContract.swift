struct HomeState: Equatable {
    var users: [UserUi] = []
    /// The server couldn't be reached; shows "Offline" next to the person.
    var isOffline = false
    var trainings: [TrainingCardUi] = []
    var isLoading = true
    /// The workout in progress, shown as a banner above the trainings.
    var activeWorkout: ActiveWorkoutUi?

    var isEmpty: Bool { !isLoading && trainings.isEmpty }
}

/// A training on Home with its counts already worded ("6 exercises", "24 sets").
struct TrainingCardUi: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let exercises: String
    let sets: String
}

struct ActiveWorkoutUi: Equatable {
    let title: String
    /// "Overhead Press · Set 2 of 3".
    let subtitle: String
    let elapsed: String
    let progress: Double
    /// "5 / 10 sets", "Rest 1:24" while a rest counts down ([progress] then drains with it), or "Rest over" once it ended.
    let progressText: String
}

enum HomeAction {
    case onAppear
    case onUserTap(id: String)
    case onCreateProfileTap
    case onInviteTap
    case onTrainingTap(id: String)
    case onAddTrainingTap
    /// Start a workout without a training, adding exercises along the way.
    case onFreeWorkoutTap
    case onActiveWorkoutTap
}

enum HomeEvent: UiEvent {
    case navigateToCreateProfile
    case navigateToInvite
    case navigateToTraining(id: String)
    case navigateToNewTraining
    /// [restExerciseIndex]: a rest is in progress, open the exercise showing its timer.
    case navigateToWorkout(restExerciseIndex: Int?)
}

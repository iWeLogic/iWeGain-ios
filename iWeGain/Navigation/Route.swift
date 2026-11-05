/// Screens pushed onto a tab's stack or shown as sheets. Cases carry IDs and primitives only;
/// the destination's ViewModel loads the data. Screens are added here as the features are built.
enum Route: Hashable, Codable {
    /// An existing training opens read-only; nil [trainingId] creates a new one in edit mode.
    case training(trainingId: String?)
    /// Picks an exercise for the training editor or free workout below it (the result goes through [Router.pickedExerciseId]).
    case exerciseLibrary
    /// The selected person's running workout (the workout itself lives in WorkoutRepository).
    case workout
    /// The exercise at [index] of the running workout; [opensLogSet] opens its Log Set sheet for the
    /// current set (Complete on the Live Activity).
    case workoutExercise(index: Int, opensLogSet: Bool = false)
    /// The result of a finished workout.
    case workoutDetails(workoutId: String)
    /// Changes the results of a finished workout.
    case editWorkout(workoutId: String)
    /// Schedules a training on the day [epochDay], or edits the occurrence of [entryId] on that day.
    case schedule(epochDay: Int, entryId: String?)
    /// Picks a training to schedule; [selectedTrainingId] starts selected (the result goes through [Router.pickedTrainingId]).
    case selectTraining(selectedTrainingId: String?)
    /// Google sign-in, on top of the screen that asked for it.
    case signIn
    /// The people in my team and the profiles I created.
    case myTeam
    /// The teams I'm a member of.
    case teamsImIn
    /// "Add a person": create a profile inside my account, or invite someone.
    case addPerson
    /// Creates and shares an invite link to my team.
    case invite
    /// A new profile (no [profileId]), a profile I created, or my own name and photo ([isMe]).
    case profileEditor(profileId: String? = nil, isMe: Bool = false)
    /// Opened from an invite link: sign in if needed, then join the team of [code]'s owner.
    case joinTeam(code: String)
    /// Every color, text style and component of the design system (opened from Settings in debug builds).
    case designCatalog
}

extension Route: Identifiable {
    var id: Self { self }
}

extension Route {
    var isWorkoutExercise: Bool {
        if case .workoutExercise = self { true } else { false }
    }

    var isJoinTeam: Bool {
        if case .joinTeam = self { true } else { false }
    }

    /// The name analytics logs for this screen (the same as Android's `NavKey.screenName`).
    var screenName: String {
        switch self {
        case .training(let trainingId): trainingId == nil ? "NewTraining" : "Training"
        case .exerciseLibrary: "ExerciseLibrary"
        case .workout: "Workout"
        case .workoutExercise: "WorkoutExercise"
        case .workoutDetails: "WorkoutDetails"
        case .editWorkout: "EditWorkout"
        case .schedule: "Schedule"
        case .selectTraining: "SelectTraining"
        case .signIn: "SignIn"
        case .myTeam: "MyTeam"
        case .teamsImIn: "TeamsImIn"
        case .addPerson: "AddPerson"
        case .invite: "Invite"
        case .profileEditor(let profileId, let isMe): isMe ? "MyProfile" : profileId == nil ? "NewProfile" : "EditProfile"
        case .joinTeam: "JoinTeam"
        case .designCatalog: "DesignCatalog"
        }
    }
}

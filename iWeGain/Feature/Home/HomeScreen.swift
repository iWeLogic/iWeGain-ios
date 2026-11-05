import SwiftUI

struct HomeRoot: View {
    @State private var viewModel: HomeViewModel
    private let onNavigateToTraining: (String) -> Void
    private let onNavigateToNewTraining: () -> Void
    private let onNavigateToWorkout: (Int?) -> Void
    private let onNavigateToCreateProfile: () -> Void
    private let onNavigateToInvite: () -> Void

    init(
        viewModel: @autoclosure () -> HomeViewModel,
        onNavigateToTraining: @escaping (String) -> Void,
        onNavigateToNewTraining: @escaping () -> Void,
        onNavigateToWorkout: @escaping (Int?) -> Void,
        onNavigateToCreateProfile: @escaping () -> Void,
        onNavigateToInvite: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToTraining = onNavigateToTraining
        self.onNavigateToNewTraining = onNavigateToNewTraining
        self.onNavigateToWorkout = onNavigateToWorkout
        self.onNavigateToCreateProfile = onNavigateToCreateProfile
        self.onNavigateToInvite = onNavigateToInvite
    }

    var body: some View {
        HomeScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToTraining(let id): onNavigateToTraining(id)
                case .navigateToNewTraining: onNavigateToNewTraining()
                case .navigateToWorkout(let restExerciseIndex): onNavigateToWorkout(restExerciseIndex)
                case .navigateToCreateProfile: onNavigateToCreateProfile()
                case .navigateToInvite: onNavigateToInvite()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

struct HomeScreen: View {
    let state: HomeState
    let onAction: (HomeAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.x12) {
                UserSwitcher(
                    users: state.users,
                    isOffline: state.isOffline,
                    onUserTap: { onAction(.onUserTap(id: $0)) },
                    onCreateProfileTap: { onAction(.onCreateProfileTap) },
                    onInviteTap: { onAction(.onInviteTap) }
                )
                if let workout = state.activeWorkout {
                    ActiveWorkoutBanner(
                        title: workout.title,
                        subtitle: workout.subtitle,
                        elapsed: workout.elapsed,
                        progress: workout.progress,
                        progressText: workout.progressText,
                        action: { onAction(.onActiveWorkoutTap) }
                    )
                }
                ForEach(state.trainings) { training in
                    TrainingCard(
                        title: training.name,
                        icon: training.icon,
                        metrics: [Metric(icon: "ic_dumbbell", text: training.exercises), Metric(icon: "ic_check", text: training.sets)],
                        action: { onAction(.onTrainingTap(id: training.id)) }
                    )
                }
                if state.isEmpty {
                    EmptyStateView(title: "home_empty_title", message: "home_empty_message", icon: "ic_dumbbell")
                }
                if !state.isLoading && state.activeWorkout == nil {
                    OptionCard(icon: "ic_play", title: "free_workout", subtitle: "home_free_workout_hint", action: { onAction(.onFreeWorkoutTap) })
                }
                if !state.isLoading {
                    AddActionCard(
                        title: state.isEmpty ? "home_create_first_training" : "home_add_training",
                        subtitle: state.isEmpty ? "home_create_first_training_hint" : "home_add_training_hint",
                        action: { onAction(.onAddTrainingTap) }
                    )
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
        }
        .background(Color.bgBase)
        .hidesNavigationBar()
    }
}

#Preview("Trainings") {
    NavigationStack {
        HomeScreen(
            state: HomeState(
                trainings: [
                    TrainingCardUi(id: "1", name: "Push Day", icon: "ic_dumbbell", exercises: "6 exercises", sets: "24 sets"),
                    TrainingCardUi(id: "2", name: "Pull Day", icon: "ic_zap", exercises: "5 exercises", sets: "20 sets"),
                    TrainingCardUi(id: "3", name: "Leg Day", icon: "ic_mountain", exercises: "5 exercises", sets: "20 sets"),
                ],
                isLoading: false,
                activeWorkout: ActiveWorkoutUi(title: "Push Day", subtitle: "Overhead Press · Set 2 of 3", elapsed: "24:13", progress: 0.5, progressText: "5 / 10 sets")
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Empty") {
    NavigationStack { HomeScreen(state: HomeState(isLoading: false), onAction: { _ in }) }
}

import SwiftUI

/// The app's navigation host: a tab bar with one navigation stack per tab, so each tab keeps its own
/// history. The only view that holds the [AppContainer]; it builds every screen from its factories.
struct AppNavigation: View {
    let container: AppContainer

    @State private var selectedTab: AppTab = .home
    @State private var routers: [AppTab: Router] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, Router()) })

    var body: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(value: tab) {
                    TabStack(router: router(for: tab)) {
                        root(for: tab)
                    } destination: { route in
                        destination(for: route, in: tab)
                    }
                } label: {
                    Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
                }
            }
        }
        .tint(Color.accentPrimary)
        .background {
            ScreenLogger(tab: selectedTab, router: router(for: selectedTab)) { container.analytics.logScreen($0) }
        }
        .onOpenURL { url in
            if container.authRepository.handle(url: url) { return }
            if let link = WorkoutLink(url: url) { open(link) }
            if let code = TeamInvite.code(fromLink: url) { openInvite(code) }
        }
        #if DEBUG
        .task {
            switch DebugLaunch.route {
            case "design-catalog":
                selectedTab = .settings
                router(for: .settings).push(.designCatalog)
            case "new-training": router(for: .home).push(.training(trainingId: nil))
            case "first-training":
                if let first = try? container.trainingRepository.allTrainings().first {
                    router(for: .home).push(.training(trainingId: first.id))
                }
            case "exercise-library": router(for: .home).push(.exerciseLibrary)
            case "workout", "workout-exercise":
                // Starts the first training's workout; "workout-exercise" also starts its first exercise and opens it.
                let workouts = container.workoutRepository
                guard let first = try? container.trainingRepository.allTrainings().first,
                      (try? workouts.startWorkout(first)) != nil else { break }
                if DebugLaunch.route == "workout-exercise" {
                    try? workouts.startExercise(exerciseIndex: 0)
                    try? workouts.endRest()
                    openWorkout(in: .home, restExerciseIndex: 0)
                } else {
                    openWorkout(in: .home, restExerciseIndex: nil)
                }
            case "sign-in":
                selectedTab = .settings
                router(for: .settings).push(.signIn)
            case "my-team":
                selectedTab = .settings
                router(for: .settings).push(.myTeam)
            case "teams-im-in":
                selectedTab = .settings
                router(for: .settings).push(.teamsImIn)
            case "my-profile":
                selectedTab = .settings
                router(for: .settings).push(.profileEditor(isMe: true))
            case "new-profile": router(for: .home).push(.profileEditor())
            case "add-person": router(for: .home).push(.addPerson)
            case "invite": router(for: .home).push(.invite)
            case "join-team": openInvite("AK7-29QX")
            case "calendar": selectedTab = .calendar
            case "statistics": selectedTab = .statistics
            case "settings": selectedTab = .settings
            case "schedule":
                selectedTab = .calendar
                router(for: .calendar).push(.schedule(epochDay: Day.today().epochDay, entryId: nil))
            case "workout-details", "edit-workout":
                selectedTab = .calendar
                if let latest = await container.workoutRepository.observeFinishedWorkouts(userId: container.userRepository.selectedUserId).first()?.first {
                    router(for: .calendar).push(.workoutDetails(workoutId: latest.id))
                    if DebugLaunch.route == "edit-workout" { router(for: .calendar).push(.editWorkout(workoutId: latest.id)) }
                }
            case "free-workout":
                if (try? container.workoutRepository.startFreeWorkout()) != nil { openWorkout(in: .home, restExerciseIndex: nil) }
            default: break
            }
        }
        #endif
    }

    /// Tapping the tab that's already selected goes back to its first screen.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                if tab == selectedTab { router(for: tab).popToRoot() }
                selectedTab = tab
            }
        )
    }

    private func router(for tab: AppTab) -> Router {
        routers[tab] ?? Router()
    }

    // MARK: Workout

    /// Opens the workout overview in [tab], in place of the training it was started from; with
    /// [restExerciseIndex] (a rest is in progress) the exercise showing its timer opens on top of it.
    private func openWorkout(in tab: AppTab, restExerciseIndex: Int?) {
        closeWorkout()
        let router = router(for: tab)
        var path = router.path
        if case .training = path.last { path.removeLast() }
        path.append(.workout)
        if let restExerciseIndex { path.append(.workoutExercise(index: restExerciseIndex)) }
        router.path = path
    }

    /// Opens the exercise at [index] on top of the workout overview, replacing any open exercise.
    private func openWorkoutExercise(_ index: Int, in tab: AppTab, opensLogSet: Bool = false) {
        let router = router(for: tab)
        var path = router.path.filter { !$0.isWorkoutExercise }
        if !path.contains(.workout) { path.append(.workout) }
        path.append(.workoutExercise(index: index, opensLogSet: opensLogSet))
        router.path = path
    }

    /// A tap on the Live Activity: the workout screen it's about, in the tab that shows the workout (Home otherwise).
    private func open(_ link: WorkoutLink) {
        guard container.workoutRepository.activeWorkout() != nil else { return }
        let tab = AppTab.allCases.first { router(for: $0).path.contains(.workout) } ?? .home
        selectedTab = tab
        switch link {
        case .overview:
            if router(for: tab).path.contains(.workout) { backToWorkout(in: tab) } else { openWorkout(in: tab, restExerciseIndex: nil) }
        case .exercise(let index, let opensLogSet):
            openWorkoutExercise(index, in: tab, opensLogSet: opensLogSet)
        }
    }

    /// Returns to the workout overview from an exercise.
    private func backToWorkout(in tab: AppTab) {
        let router = router(for: tab)
        router.path = router.path.filter { !$0.isWorkoutExercise }
    }

    /// Leaves the workout screens in every tab after the workout is finished.
    private func closeWorkout() {
        for router in routers.values {
            let path = router.path.filter { $0 != .workout && !$0.isWorkoutExercise }
            if path != router.path { router.path = path }
        }
    }

    /// An invite link opens the join flow on top of the current tab, in place of one already open.
    private func openInvite(_ code: String) {
        let router = router(for: selectedTab)
        router.path.removeAll { $0.isJoinTeam }
        router.push(.joinTeam(code: code))
    }

    @ViewBuilder
    private func root(for tab: AppTab) -> some View {
        let router = router(for: tab)
        switch tab {
        case .home:
            HomeRoot(
                viewModel: container.makeHomeViewModel(),
                onNavigateToTraining: { router.push(.training(trainingId: $0)) },
                onNavigateToNewTraining: { router.push(.training(trainingId: nil)) },
                onNavigateToWorkout: { openWorkout(in: tab, restExerciseIndex: $0) },
                onNavigateToCreateProfile: { router.push(.profileEditor()) },
                onNavigateToInvite: { router.push(.invite) }
            )
        case .calendar:
            CalendarRoot(
                viewModel: container.makeCalendarViewModel(),
                onNavigateToWorkoutDetails: { router.push(.workoutDetails(workoutId: $0)) },
                onNavigateToSchedule: { date, entryId in router.push(.schedule(epochDay: date.epochDay, entryId: entryId)) },
                onNavigateToCreateProfile: { router.push(.profileEditor()) },
                onNavigateToInvite: { router.push(.invite) }
            )
        case .statistics:
            StatisticsRoot(
                viewModel: container.makeStatisticsViewModel(),
                onNavigateToCreateProfile: { router.push(.profileEditor()) },
                onNavigateToInvite: { router.push(.invite) },
                onNavigateToNewTraining: { router.push(.training(trainingId: nil)) }
            )
        case .settings:
            SettingsRoot(
                viewModel: container.makeSettingsViewModel(),
                onNavigateToSignIn: { router.push(.signIn) },
                onNavigateToMyTeam: { router.push(.myTeam) },
                onNavigateToMyProfile: { router.push(.profileEditor(isMe: true)) },
                onNavigateToTeamsImIn: { router.push(.teamsImIn) },
                onDesignCatalogTap: { router.push(.designCatalog) }
            )
        }
    }

    @ViewBuilder
    private func destination(for route: Route, in tab: AppTab) -> some View {
        let router = router(for: tab)
        switch route {
        case .training(let trainingId):
            PickedExerciseReader(router: router) { pickedExerciseId in
                TrainingRoot(
                    viewModel: container.makeTrainingViewModel(trainingId: trainingId),
                    pickedExerciseId: pickedExerciseId,
                    onPickedExerciseHandled: { router.pickedExerciseId = nil },
                    onNavigateToExerciseLibrary: { router.push(.exerciseLibrary) },
                    onNavigateToWorkout: { openWorkout(in: tab, restExerciseIndex: $0) },
                    onClose: { router.pop() }
                )
            }
            .hidesTabBar()
        case .workout:
            PickedExerciseReader(router: router) { pickedExerciseId in
                WorkoutRoot(
                    viewModel: container.makeWorkoutViewModel(),
                    pickedExerciseId: pickedExerciseId,
                    onPickedExerciseHandled: { router.pickedExerciseId = nil },
                    onNavigateToExercise: { openWorkoutExercise($0, in: tab) },
                    onNavigateToExerciseLibrary: { router.push(.exerciseLibrary) },
                    onClose: { closeWorkout() }
                )
            }
            .hidesTabBar()
        case .workoutExercise(let index, let opensLogSet):
            ExerciseRoot(
                viewModel: container.makeExerciseViewModel(exerciseIndex: index, opensLogSet: opensLogSet),
                onBackToWorkout: { backToWorkout(in: tab) },
                onNavigateToExercise: { openWorkoutExercise($0, in: tab) }
            )
            .id(route)
            .hidesTabBar()
        case .exerciseLibrary:
            ExerciseLibraryRoot(
                viewModel: container.makeExerciseLibraryViewModel(),
                onExercisePicked: { router.returnPickedExercise($0) }
            )
            .hidesTabBar()
        case .workoutDetails(let workoutId):
            WorkoutDetailsRoot(
                viewModel: container.makeWorkoutDetailsViewModel(workoutId: workoutId),
                onNavigateToEdit: { router.push(.editWorkout(workoutId: workoutId)) },
                onClose: { router.path.removeAll { $0 == route } }
            )
            .hidesTabBar()
        case .editWorkout(let workoutId):
            PickedExerciseReader(router: router) { pickedExerciseId in
                EditWorkoutRoot(
                    viewModel: container.makeEditWorkoutViewModel(workoutId: workoutId),
                    pickedExerciseId: pickedExerciseId,
                    onPickedExerciseHandled: { router.pickedExerciseId = nil },
                    onNavigateToExerciseLibrary: { router.push(.exerciseLibrary) },
                    onClose: { router.path.removeAll { $0 == route } }
                )
            }
            .hidesTabBar()
        case .schedule(let epochDay, let entryId):
            PickedTrainingReader(router: router) { pickedTrainingId in
                ScheduleRoot(
                    viewModel: container.makeScheduleViewModel(date: Day(epochDay: epochDay), entryId: entryId),
                    pickedTrainingId: pickedTrainingId,
                    onPickedTrainingHandled: { router.pickedTrainingId = nil },
                    onNavigateToSelectTraining: { router.push(.selectTraining(selectedTrainingId: $0)) },
                    onClose: { router.pop() }
                )
            }
            .hidesTabBar()
        case .selectTraining(let selectedTrainingId):
            SelectTrainingRoot(
                viewModel: container.makeSelectTrainingViewModel(selectedTrainingId: selectedTrainingId),
                onSelected: { router.returnPickedTraining($0) },
                onNavigateToCreateTraining: { router.push(.training(trainingId: nil)) }
            )
            .hidesTabBar()
        case .signIn:
            SignInRoot(
                viewModel: container.makeSignInViewModel(),
                onClose: { router.remove(.signIn) }
            )
            .hidesTabBar()
        case .myTeam:
            MyTeamRoot(
                viewModel: container.makeMyTeamViewModel(),
                onNavigateToInvite: { router.push(.invite) },
                onNavigateToCreateProfile: { router.push(.profileEditor()) },
                onNavigateToEditProfile: { router.push(.profileEditor(profileId: $0)) }
            )
            .hidesTabBar()
        case .teamsImIn:
            TeamsImInRoot(viewModel: container.makeTeamsImInViewModel())
                .hidesTabBar()
        case .addPerson:
            AddPersonChoiceRoot(
                viewModel: container.makeAddPersonChoiceViewModel(),
                // Each choice takes this screen's place, so closing it goes back to where "Add" was tapped.
                onNavigateToCreateProfile: { router.replace(.profileEditor()) },
                onNavigateToInvite: { router.replace(.invite) },
                onNavigateToSignIn: { router.push(.signIn) },
                onClose: { router.remove(route) }
            )
            .hidesTabBar()
        case .invite:
            AddPersonRoot(
                viewModel: container.makeAddPersonViewModel(),
                onNavigateToSignIn: { router.push(.signIn) },
                onClose: { router.remove(route) }
            )
            .hidesTabBar()
        case .profileEditor(let profileId, let isMe):
            ProfileEditorRoot(
                viewModel: container.makeProfileEditorViewModel(mode: isMe ? .me : profileId.map { .edit(profileId: $0) } ?? .new),
                onClose: { router.remove(route) }
            )
            .hidesTabBar()
        case .joinTeam(let code):
            JoinTeamRoot(
                viewModel: container.makeJoinTeamViewModel(code: code),
                onClose: { router.remove(route) }
            )
            .id(route)
            .hidesTabBar()
        case .designCatalog: DesignCatalogScreen()
        }
    }
}

/// Logs each screen that comes on top of the selected tab, in its own body so that navigating doesn't
/// rebuild the whole navigation host.
private struct ScreenLogger: View {
    let tab: AppTab
    let router: Router
    let onScreenShown: (String) -> Void

    var body: some View {
        Color.clear.onChange(of: router.path.last?.screenName ?? tab.screenName, initial: true) { _, screen in
            onScreenShown(screen)
        }
    }
}

/// Reads the router's picked exercise in its own body, so the training editor or workout sees each new pick.
private struct PickedExerciseReader<Content: View>: View {
    let router: Router
    @ViewBuilder let content: (String?) -> Content

    var body: some View {
        content(router.pickedExerciseId)
    }
}

/// Reads the router's picked training in its own body, so the schedule form sees each new pick.
private struct PickedTrainingReader<Content: View>: View {
    let router: Router
    @ViewBuilder let content: (String?) -> Content

    var body: some View {
        content(router.pickedTrainingId)
    }
}

/// One tab's navigation stack, with its sheet.
private struct TabStack<Root: View, Destination: View>: View {
    @Bindable var router: Router
    @ViewBuilder let root: () -> Root
    @ViewBuilder let destination: (Route) -> Destination

    var body: some View {
        NavigationStack(path: $router.path) {
            root()
                .navigationDestination(for: Route.self) { destination($0) }
        }
        .sheet(item: $router.sheet) { route in
            NavigationStack { destination(route) }
        }
    }
}

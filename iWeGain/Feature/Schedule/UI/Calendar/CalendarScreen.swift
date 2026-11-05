import SwiftUI

struct CalendarRoot: View {
    @State private var viewModel: CalendarViewModel
    private let onNavigateToWorkoutDetails: (String) -> Void
    private let onNavigateToSchedule: (Day, String?) -> Void
    private let onNavigateToCreateProfile: () -> Void
    private let onNavigateToInvite: () -> Void

    init(
        viewModel: @autoclosure () -> CalendarViewModel,
        onNavigateToWorkoutDetails: @escaping (String) -> Void,
        onNavigateToSchedule: @escaping (Day, String?) -> Void,
        onNavigateToCreateProfile: @escaping () -> Void,
        onNavigateToInvite: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToWorkoutDetails = onNavigateToWorkoutDetails
        self.onNavigateToSchedule = onNavigateToSchedule
        self.onNavigateToCreateProfile = onNavigateToCreateProfile
        self.onNavigateToInvite = onNavigateToInvite
    }

    var body: some View {
        CalendarScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToWorkoutDetails(let workoutId): onNavigateToWorkoutDetails(workoutId)
                case .navigateToSchedule(let date, let entryId): onNavigateToSchedule(date, entryId)
                case .navigateToCreateProfile: onNavigateToCreateProfile()
                case .navigateToInvite: onNavigateToInvite()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

struct CalendarScreen: View {
    let state: CalendarState
    let onAction: (CalendarAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.x16) {
                UserSwitcher(
                    users: state.users,
                    isOffline: state.isOffline,
                    onUserTap: { onAction(.onUserTap(id: $0)) },
                    onCreateProfileTap: { onAction(.onCreateProfileTap) },
                    onInviteTap: { onAction(.onInviteTap) }
                )
                MonthCalendar(
                    title: state.monthTitle,
                    weekdayLabels: state.weekdayLabels,
                    weeks: state.weeks,
                    onPreviousTap: { onAction(.onPreviousMonthTap) },
                    onNextTap: { onAction(.onNextMonthTap) },
                    onDayTap: { onAction(.onDayTap($0)) }
                )
                if state.isDayEmpty {
                    EmptyStateView(title: "calendar_empty_title", message: "calendar_empty_message")
                        .padding(.vertical, Spacing.x8)
                } else {
                    Text(state.selectedDateTitle)
                        .textStyle(.title2)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(state.completed) { workout in
                        TrainingCard(
                            title: workout.title,
                            icon: workout.icon,
                            subtitle: workout.exercises,
                            metrics: [Metric(icon: "ic_clock", text: workout.duration), Metric(icon: "ic_check", text: workout.doneSets)],
                            trailing: StatusChip.completed,
                            action: { onAction(.onWorkoutTap(id: workout.id)) }
                        )
                    }
                    ForEach(state.planned) { planned in
                        PlannedTrainingCard(
                            icon: planned.icon,
                            title: planned.title,
                            time: planned.time,
                            repeats: planned.repeats,
                            status: planned.isMissed ? .missed : .scheduled,
                            action: { onAction(.onPlannedTap(entryId: planned.id)) }
                        )
                    }
                }
                Button { onAction(.onScheduleTap) } label: {
                    Label { Text("calendar_schedule_training") } icon: { Image("ic_plus") }
                }
                .buttonStyle(.appPrimary)
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
        }
        .background(Color.bgBase)
        .hidesNavigationBar()
    }
}

#Preview {
    let today = Day(year: 2026, month: 9, day: 29)
    let start = Day(year: 2026, month: 8, day: 31)
    let weeks = (0..<5).map { week in
        (0..<7).map { offset in
            let date = start.adding(days: week * 7 + offset)
            return CalendarDayUi(date: date, inMonth: date.month == 9, isToday: date == today, isSelected: date == today,
                                 mark: date == today ? .completed : .none)
        }
    }
    NavigationStack {
        CalendarScreen(
            state: CalendarState(
                monthTitle: "September 2026",
                weekdayLabels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                weeks: weeks,
                selectedDate: today,
                selectedDateTitle: "Tue, Sep 29",
                completed: [CompletedWorkoutUi(id: "w1", title: "Push Day", icon: "ic_dumbbell", exercises: "4 exercises",
                                               duration: "1 h 12 min", doneSets: "13 sets")],
                planned: [PlannedTrainingUi(id: "p1", icon: "ic_zap", title: "Pull Day", time: "18:00 – 19:00", isMissed: false, repeats: true)]
            ),
            onAction: { _ in }
        )
    }
}

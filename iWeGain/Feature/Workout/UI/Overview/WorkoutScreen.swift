import SwiftUI

struct WorkoutRoot: View {
    @State private var viewModel: WorkoutViewModel
    @State private var errorMessage: LocalizedStringResource?
    /// An exercise picked in the library, handed over by the navigation; [onPickedExerciseHandled] clears it.
    private let pickedExerciseId: String?
    private let onPickedExerciseHandled: () -> Void
    private let onNavigateToExercise: (Int) -> Void
    private let onNavigateToExerciseLibrary: () -> Void
    private let onClose: () -> Void

    init(
        viewModel: @autoclosure () -> WorkoutViewModel,
        pickedExerciseId: String?,
        onPickedExerciseHandled: @escaping () -> Void,
        onNavigateToExercise: @escaping (Int) -> Void,
        onNavigateToExerciseLibrary: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.pickedExerciseId = pickedExerciseId
        self.onPickedExerciseHandled = onPickedExerciseHandled
        self.onNavigateToExercise = onNavigateToExercise
        self.onNavigateToExerciseLibrary = onNavigateToExerciseLibrary
        self.onClose = onClose
    }

    var body: some View {
        WorkoutScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToExercise(let index): onNavigateToExercise(index)
                case .navigateToExerciseLibrary: onNavigateToExerciseLibrary()
                case .close: onClose()
                case .showError(let message): errorMessage = message
                }
            }
            .errorAlert($errorMessage)
            .keepsScreenOn()
            .task { viewModel.onAction(.onAppear) }
            .onChange(of: pickedExerciseId, initial: true) { _, id in
                guard let id else { return }
                viewModel.onAction(.onExercisePicked(id: id))
                onPickedExerciseHandled()
            }
    }
}

struct WorkoutScreen: View {
    let state: WorkoutState
    let onAction: (WorkoutAction) -> Void

    var body: some View {
        ScrollView {
            if state.isLoaded {
                LazyVStack(spacing: Spacing.x12) {
                    Header(state: state)
                        .padding(.bottom, Spacing.x8)
                    HStack(spacing: Spacing.x12) {
                        StatTile(label: "workout_sets_done", value: state.setsProgress, caption: state.setsCaption)
                        StatTile(label: "workout_volume", value: state.volume, caption: Strings.text("workout_volume_caption"))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Text("workout_exercises")
                        .textStyle(.title2)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.x8)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(state.exercises) { exercise in
                        WorkoutExerciseRow(
                            icon: exercise.icon,
                            title: exercise.name,
                            subtitle: exercise.subtitle,
                            status: exercise.status,
                            action: { onAction(.onExerciseTap(index: exercise.index)) }
                        )
                    }
                    if state.isFree {
                        AddActionCard(
                            title: "training_add_exercise",
                            subtitle: "training_add_exercise_hint",
                            action: { onAction(.onAddExerciseTap) }
                        )
                    } else {
                        SwitchToFree(trainingName: state.title, action: { onAction(.onSwitchToFreeTap) })
                    }
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.top, Spacing.x4)
                .padding(.bottom, Spacing.x8)
                // Slides a row to its new place when it starts (it moves behind the finished exercises).
                .animation(.default, value: state.exercises.map(\.index))
            }
        }
        .background(Color.bgBase)
        .safeAreaInset(edge: .bottom) {
            if state.isLoaded {
                BottomButton(state: state, onAction: onAction)
                    .padding(.horizontal, Spacing.x16)
                    .padding(.top, Spacing.x12)
                    .padding(.bottom, Spacing.x8)
                    .background(Color.bgBase)
            }
        }
        .inlineNavigationTitle()
        .toolbar {
            if !state.elapsed.isEmpty {
                ToolbarItem(placement: .primaryAction) { ElapsedChip(text: state.elapsed) }
            }
        }
        .alert(
            Text("workout_switch_title"),
            isPresented: Binding(get: { state.isSwitchConfirmOpen }, set: { if !$0 { onAction(.onSwitchToFreeDismiss) } }),
            actions: {
                Button("workout_switch") { onAction(.onSwitchToFreeConfirm) }
                Button(Strings.format("workout_switch_keep", state.title), role: .cancel) { onAction(.onSwitchToFreeDismiss) }
            },
            message: { Text(Strings.format("workout_switch_message", state.title, Strings.text("free_workout"))) }
        )
        .sheet(isPresented: Binding(get: { state.finish != nil }, set: { if !$0 { onAction(.onFinishDismiss) } })) {
            if let summary = state.finish {
                FinishWorkoutSheet(
                    title: state.title,
                    elapsed: state.elapsed,
                    summary: summary,
                    name: state.finishName,
                    onAction: onAction
                )
            }
        }
    }
}

private struct Header: View {
    let state: WorkoutState

    var body: some View {
        HStack(spacing: Spacing.x12) {
            if let icon = state.icon { IconBadge(asset: icon) }
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(state.title)
                    .textStyle(.title2)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(state.startedAt)
                    .textStyle(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// "Start workout" for a free workout that waits for it, otherwise Finish workout (primary once every set is done).
private struct BottomButton: View {
    let state: WorkoutState
    let onAction: (WorkoutAction) -> Void

    var body: some View {
        if !state.isStarted {
            Button { onAction(.onStartWorkoutTap) } label: { IconLabel("workout_start", icon: "ic_play") }
                .buttonStyle(.appPrimary)
        } else {
            Button { onAction(.onFinishTap) } label: { IconLabel("workout_finish", icon: "ic_trophy") }
                .buttonStyle(state.allSetsDone ? .appPrimary : .appSecondary)
        }
    }
}

/// Figma "12h": a training's exercises are fixed; this makes the workout free to add more.
private struct SwitchToFree: View {
    let trainingName: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.x2) {
            Button(action: action) {
                IconLabel("workout_switch", icon: "ic_repeat", iconSize: 18)
                    .textStyle(.subhead)
                    .foregroundStyle(Color.accentPrimary)
                    .padding(Spacing.x12)
                    .contentShape(.rect(cornerRadius: Radius.sm))
            }
            .buttonStyle(.pressable)
            Text(Strings.format("workout_switch_hint", trainingName))
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Workout") {
    NavigationStack {
        WorkoutScreen(
            state: WorkoutState(
                isLoaded: true,
                title: "Push Day",
                icon: "ic_dumbbell",
                startedAt: "Started 18:05",
                elapsed: "24:13",
                setsProgress: "5 / 10",
                setsCaption: "5 left",
                volume: "3,240 kg",
                exercises: [
                    WorkoutExerciseUi(index: 0, icon: "ic_ex_barbell_bench_press", name: "Bench Press", subtitle: "4 of 4 sets · best 100 kg × 5", status: .done),
                    WorkoutExerciseUi(index: 1, icon: "ic_ex_overhead_barbell_press", name: "Overhead Press", subtitle: "1 of 3 sets done · tap to continue", status: .active),
                    WorkoutExerciseUi(index: 2, icon: "ic_ex_triceps_pushdown", name: "Triceps Pushdown", subtitle: "3 sets · rest 60 s", status: .upcoming),
                ]
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Free, not started") {
    NavigationStack {
        WorkoutScreen(
            state: WorkoutState(isLoaded: true, title: "Free workout · Nov 1", icon: "ic_activity", startedAt: "Not started yet",
                                elapsed: "0:00", setsProgress: "0", setsCaption: "No sets yet", volume: "0 kg", isFree: true, isStarted: false),
            onAction: { _ in }
        )
    }
}

import SwiftUI

struct ExerciseRoot: View {
    @State private var viewModel: ExerciseViewModel
    @State private var errorMessage: LocalizedStringResource?
    @State private var restOverCount = 0
    private let onBackToWorkout: () -> Void
    private let onNavigateToExercise: (Int) -> Void

    init(
        viewModel: @autoclosure () -> ExerciseViewModel,
        onBackToWorkout: @escaping () -> Void,
        onNavigateToExercise: @escaping (Int) -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onBackToWorkout = onBackToWorkout
        self.onNavigateToExercise = onNavigateToExercise
    }

    var body: some View {
        ExerciseScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .backToWorkout: onBackToWorkout()
                case .restOver: restOverCount += 1
                case .navigateToExercise(let index): onNavigateToExercise(index)
                case .showError(let message): errorMessage = message
                }
            }
            .sensoryFeedback(.success, trigger: restOverCount)
            .errorAlert($errorMessage)
            .keepsScreenOn()
            .task { viewModel.onAction(.onAppear) }
    }
}

struct ExerciseScreen: View {
    let state: ExerciseState
    let onAction: (ExerciseAction) -> Void

    var body: some View {
        ScrollView {
            if state.isLoaded {
                VStack(alignment: .leading, spacing: 0) {
                    Header(state: state, onAction: onAction)
                        .padding(.horizontal, Spacing.x16)
                        .padding(.vertical, Spacing.x8)
                    VStack(spacing: Spacing.x16) {
                        RestCard(rest: state.rest, canAddTime: state.phase == .running, onAction: onAction)
                        SetList(state: state, onAction: onAction)
                        if let restInfo = state.restInfo {
                            HStack(spacing: Spacing.x8) {
                                Image("ic_clock").resizable().frame(width: 16, height: 16)
                                Text(restInfo).textStyle(.footnote)
                            }
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, Spacing.x4)
                        }
                    }
                    .padding(.horizontal, Spacing.x16)
                    .padding(.vertical, Spacing.x12)
                }
            }
        }
        .background(Color.bgBase)
        .overlay(alignment: .bottom) {
            if let number = state.skippedSetNumber {
                StatusPill(
                    text: Strings.format("exercise_set_skipped_toast", number),
                    icon: "ic_skip_forward",
                    background: .bgSurface2,
                    iconColor: .textPrimary,
                    actionTitle: "action_undo",
                    action: { onAction(.onUndoSkipTap) }
                )
                .padding(.bottom, Spacing.x8)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.skippedSetNumber)
        .safeAreaInset(edge: .bottom) {
            if state.isLoaded {
                BottomActions(state: state, onAction: onAction)
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
        .sheet(isPresented: Binding(get: { state.logSet != nil }, set: { if !$0 { onAction(.onLogSet(.onDismiss)) } })) {
            if let logSet = state.logSet {
                NavigationStack {
                    LogSetSheet(logSet: logSet, onAction: { onAction(.onLogSet($0)) })
                }
                .presentationDetents([.large])
            }
        }
        .alert(
            Text(Strings.format("exercise_remove_title", state.name)),
            isPresented: Binding(get: { state.isRemoveConfirmOpen }, set: { if !$0 { onAction(.onRemoveExerciseDismiss) } }),
            actions: {
                Button("exercise_remove_confirm", role: .destructive) { onAction(.onRemoveExerciseConfirm) }
                Button("action_cancel", role: .cancel) { onAction(.onRemoveExerciseDismiss) }
            },
            message: { Text("exercise_remove_message") }
        )
        .alert(
            Text("exercise_change_title"),
            isPresented: Binding(
                get: { state.isChangeDialogOpen && state.blockingExercise != nil },
                set: { if !$0 { onAction(.onChangeExerciseDismiss) } }
            ),
            actions: {
                let running = state.blockingExercise?.name ?? ""
                Button(Strings.format("exercise_go_to", running)) { onAction(.onGoToRunningTap) }
                Button("exercise_change") { onAction(.onChangeExerciseConfirm) }
                Button("action_cancel", role: .cancel) { onAction(.onChangeExerciseDismiss) }
            },
            message: { Text(Strings.format("exercise_change_message", state.blockingExercise?.name ?? "")) }
        )
    }
}

private struct Header: View {
    let state: ExerciseState
    let onAction: (ExerciseAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack(spacing: Spacing.x12) {
                Text(state.name)
                    .textStyle(.largeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if state.canRemoveExercise {
                    Button { onAction(.onRemoveExerciseTap) } label: {
                        Image("ic_trash")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.statusDanger)
                            .frame(width: 44, height: 44)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text("workout_remove_exercise"))
                }
            }
            Text(state.subtitle)
                .textStyle(.callout)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

/// The rest timer (Figma "16 · Exercise · Resting"): −15 s / ring / +15 s, then Pause and Cancel.
/// It stays on screen at 0:00 when there is no rest; the controls only work while one runs, except
/// +15 s, which also works while the exercise is running (it starts a rest).
private struct RestCard: View {
    let rest: RestUi
    let canAddTime: Bool
    let onAction: (ExerciseAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x16) {
            HStack(spacing: Spacing.x12) {
                // The chips share the space left by the ring, so longer units ("15초", "15 sn") still fit.
                Chip(label: "rest_minus", isSelected: false, action: { onAction(.onRestMinusTap) })
                    .disabled(!rest.isRunning)
                    .opacity(rest.isRunning ? 1 : 0.4)
                    .frame(maxWidth: .infinity)
                CountdownRing(
                    progress: { rest.progress(at: $0) },
                    label: rest.label,
                    time: rest.remaining,
                    caption: Strings.format("rest_of", rest.total)
                )
                // Also once the rest is over or cancelled: while the exercise runs it starts a short extra rest.
                Chip(label: "rest_plus", isSelected: false, action: { onAction(.onRestPlusTap) })
                    .disabled(!(rest.isActive || canAddTime))
                    .opacity(rest.isActive || canAddTime ? 1 : 0.4)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: Spacing.x12) {
                Button { onAction(.onRestPauseTap) } label: {
                    IconLabel(rest.isPaused ? "rest_resume" : "rest_pause", icon: rest.isPaused ? "ic_play" : "ic_pause")
                }
                .buttonStyle(.appSecondary)
                Button { onAction(.onRestCancelTap) } label: { IconLabel("action_cancel", icon: "ic_x") }
                    .buttonStyle(.appSecondary)
            }
            .disabled(!rest.isRunning)
        }
        .padding(.horizontal, Spacing.x12)
        .padding(.top, Spacing.x24)
        .padding(.bottom, Spacing.x12)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct SetList: View {
    let state: ExerciseState
    let onAction: (ExerciseAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x2) {
            ForEach(state.sets) { set in
                WorkoutSetRow(
                    number: set.number,
                    weight: set.weight,
                    reps: set.reps,
                    status: set.status,
                    label: set.status == .current ? "exercise_set_now" : set.status == .skipped ? "exercise_set_skipped" : nil,
                    onRetry: set.canRetry ? { onAction(.onRetrySetTap(number: set.number)) } : nil,
                    onEdit: set.canEdit ? { onAction(.onEditSetTap(number: set.number)) } : nil
                )
            }
            if state.canAddSet {
                Button { onAction(.onAddSetTap) } label: {
                    IconLabel("workout_edit_add_set", icon: "ic_plus", iconSize: 18)
                        .textStyle(.subhead)
                        .foregroundStyle(Color.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.x12)
                        .contentShape(.rect(cornerRadius: Radius.md))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Spacing.x8)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct BottomActions: View {
    let state: ExerciseState
    let onAction: (ExerciseAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x12) {
            switch state.phase {
            case .running:
                HStack(spacing: Spacing.x8) {
                    Button { onAction(.onSkipSetTap) } label: { IconLabel("exercise_skip_set", icon: "ic_skip_forward") }
                        .buttonStyle(.appSecondary)
                    Button { onAction(.onCompleteSetTap) } label: { IconLabel("exercise_complete_set", icon: "ic_check") }
                        .buttonStyle(.appPrimary)
                }
            case .ready, .skipped:
                if state.blockingExercise != nil {
                    // Only one exercise runs at a time: the dialog offers to go to it or to switch.
                    Button { onAction(.onChangeExerciseTap) } label: { IconLabel("exercise_change", icon: "ic_repeat") }
                        .buttonStyle(.appPrimary)
                } else {
                    Button { onAction(.onStartExerciseTap) } label: { IconLabel("exercise_start", icon: "ic_play") }
                        .buttonStyle(.appPrimary)
                        .disabled(!state.isWorkoutStarted)
                    if !state.isWorkoutStarted {
                        Text("exercise_start_workout_first")
                            .textStyle(.footnote)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            case .done:
                Button("exercise_back_to_workout") { onAction(.onContinueTap) }
                    .buttonStyle(.appPrimary)
            }
        }
    }
}

#Preview("Resting") {
    NavigationStack {
        ExerciseScreen(
            state: ExerciseState(
                isLoaded: true,
                elapsed: "26:02",
                name: "Overhead Press",
                subtitle: "Shoulders · Barbell · Exercise 2 of 3",
                sets: [
                    SetRowUi(number: 1, weight: "50 kg", reps: "× 8", status: .done, canEdit: true),
                    SetRowUi(number: 2, weight: "57.5 kg", reps: "× 8", status: .done, canEdit: true),
                    SetRowUi(number: 3, weight: "60 kg", reps: "× 6", status: .current),
                ],
                restInfo: "Rest 2 min between sets",
                phase: .running,
                rest: RestUi(isActive: true, endsAt: .now.addingTimeInterval(84), durationSeconds: 120, remaining: "1:24", total: "2:00", isOver: false)
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Ready") {
    NavigationStack {
        ExerciseScreen(
            state: ExerciseState(
                isLoaded: true,
                elapsed: "24:13",
                name: "Overhead Press",
                subtitle: "Shoulders · Barbell · Exercise 2 of 3",
                sets: [
                    SetRowUi(number: 1, weight: "50 kg", reps: "× 8", status: .upcoming),
                    SetRowUi(number: 2, weight: "55 kg", reps: "× 8", status: .upcoming),
                ],
                restInfo: "Rest 2 min between sets",
                rest: RestUi(durationSeconds: 120, total: "2:00")
            ),
            onAction: { _ in }
        )
    }
}

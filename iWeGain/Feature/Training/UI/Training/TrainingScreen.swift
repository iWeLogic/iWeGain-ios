import SwiftUI

struct TrainingRoot: View {
    @State private var viewModel: TrainingViewModel
    @State private var errorMessage: LocalizedStringResource?
    /// An exercise picked in the library, handed over by the navigation; [takePickedExercise] takes it, once.
    private let pickedExerciseId: String?
    private let takePickedExercise: () -> String?
    private let onNavigateToExerciseLibrary: () -> Void
    private let onNavigateToWorkout: (Int?) -> Void
    private let onClose: () -> Void

    init(
        viewModel: @autoclosure () -> TrainingViewModel,
        pickedExerciseId: String?,
        takePickedExercise: @escaping () -> String?,
        onNavigateToExerciseLibrary: @escaping () -> Void,
        onNavigateToWorkout: @escaping (Int?) -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.pickedExerciseId = pickedExerciseId
        self.takePickedExercise = takePickedExercise
        self.onNavigateToExerciseLibrary = onNavigateToExerciseLibrary
        self.onNavigateToWorkout = onNavigateToWorkout
        self.onClose = onClose
    }

    var body: some View {
        TrainingScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToExerciseLibrary: onNavigateToExerciseLibrary()
                case .navigateToWorkout(let restExerciseIndex): onNavigateToWorkout(restExerciseIndex)
                case .close: onClose()
                case .showError(let message): errorMessage = message
                }
            }
            .errorAlert($errorMessage)
            .task { viewModel.onAction(.onAppear) }
            .onChange(of: pickedExerciseId, initial: true) { _, id in
                // Taking the pick clears it: this can run twice for one pick (the change, then "initial" as the
                // view reappears, both with the old value), and only the first run may use it.
                guard id != nil, let id = takePickedExercise() else { return }
                viewModel.onAction(.onExercisePicked(id: id))
            }
    }
}

struct TrainingScreen: View {
    let state: TrainingState
    let onAction: (TrainingAction) -> Void

    var body: some View {
        List {
            if state.isLoaded {
                NameRow(state: state, onAction: onAction)
                    .padding(.top, Spacing.x8)
                    .padding(.bottom, Spacing.x8)
                    .cardRow()
                SectionLabel(text: state.exercisesLabel, trailing: state.reorderHint)
                    .cardRow()
                ForEach(state.exercises) { exercise in
                    ExerciseItem(exercise: exercise, isEditing: state.isEditing, onAction: onAction)
                        .cardRow()
                }
                .onMove(perform: state.isEditing ? { onAction(.onMoveExercises(from: $0, to: $1)) } : nil)
                if state.isEditing {
                    EditFooter(state: state, onAction: onAction)
                        .cardRow()
                } else {
                    StartFooter(state: state, onAction: onAction)
                        .padding(.top, Spacing.x8)
                        .cardRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bgBase)
        .animation(.default, value: state.exercises.map(\.id))
        .navigationTitle(Text("training_title"))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden(state.isEditing)
        .toolbar {
            if state.isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action_cancel") { onAction(.onCancelTap) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action_save") { onAction(.onSaveTap) }.tint(Color.accentPrimary)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("action_edit") { onAction(.onEditTap) }.tint(Color.accentPrimary)
                }
            }
        }
        .alert(
            Text(Strings.format("training_delete_title", state.deleteConfirmName ?? "")),
            isPresented: Binding(get: { state.deleteConfirmName != nil }, set: { if !$0 { onAction(.onDeleteDismiss) } }),
            actions: {
                Button("action_delete", role: .destructive) { onAction(.onDeleteConfirm) }
                Button("action_cancel", role: .cancel) { onAction(.onDeleteDismiss) }
            },
            message: { Text("training_delete_message") }
        )
        .sheet(isPresented: Binding(get: { state.isIconPickerOpen }, set: { if !$0 { onAction(.onIconPickerDismiss) } })) {
            IconPickerSheet(selection: state.icon, onSelect: { onAction(.onIconSelect($0)) })
        }
    }
}

private struct NameRow: View {
    let state: TrainingState
    let onAction: (TrainingAction) -> Void

    var body: some View {
        HStack(spacing: Spacing.x12) {
            if let icon = state.icon {
                IconOption(icon: icon.imageName, isSelected: true, action: { onAction(.onIconTap) }, size: 46, isEnabled: state.isEditing)
                    .accessibilityLabel(Text("training_change_icon"))
            } else {
                EmptyIconOption(action: { onAction(.onIconTap) }, size: 46, isError: state.isIconMissing)
                    .accessibilityLabel(Text("training_choose_icon"))
            }
            AppTextField(
                placeholder: "training_name",
                text: state.name,
                onTextChange: { onAction(.onNameChange($0)) },
                dashedWhenEmpty: true,
                isEnabled: state.isEditing,
                isError: state.isNameMissing
            )
        }
    }
}

private struct ExerciseItem: View {
    let exercise: ExerciseDraftUi
    let isEditing: Bool
    let onAction: (TrainingAction) -> Void

    var body: some View {
        if isEditing {
            ExerciseEditCard(
                icon: exercise.icon, title: exercise.name, subtitle: exercise.subtitle, sets: exercise.sets, rest: exercise.rest,
                onSetsDecrease: { onAction(.onSetsDecrease(id: exercise.id)) },
                onSetsIncrease: { onAction(.onSetsIncrease(id: exercise.id)) },
                onRestDecrease: { onAction(.onRestDecrease(id: exercise.id)) },
                onRestIncrease: { onAction(.onRestIncrease(id: exercise.id)) },
                onRemove: { onAction(.onRemoveExercise(id: exercise.id)) },
                canDecreaseSets: exercise.canDecreaseSets, canIncreaseSets: exercise.canIncreaseSets,
                canDecreaseRest: exercise.canDecreaseRest, canIncreaseRest: exercise.canIncreaseRest
            )
        } else {
            ExerciseViewCard(icon: exercise.icon, title: exercise.name, subtitle: exercise.subtitle, sets: exercise.sets, rest: exercise.rest)
        }
    }
}

private struct EditFooter: View {
    let state: TrainingState
    let onAction: (TrainingAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x12) {
            AddActionCard(
                title: "training_add_exercise",
                subtitle: "training_add_exercise_hint",
                action: { onAction(.onAddExerciseTap) },
                isError: state.isExercisesMissing
            )
            Button { onAction(.onSaveTap) } label: {
                Label { Text("training_save") } icon: { Image("ic_check").resizable().frame(width: 20, height: 20) }
            }
            .buttonStyle(.appPrimary)
            .padding(.top, Spacing.x8)
            if !state.isNew {
                Button { onAction(.onDeleteTap) } label: {
                    Label { Text("training_delete") } icon: { Image("ic_trash").resizable().frame(width: 20, height: 20) }
                }
                .buttonStyle(.appDanger)
                .disabled(state.isDeleting)
            }
        }
    }
}

/// Start or continue this training's workout; only one workout runs at a time, so another one blocks it.
private struct StartFooter: View {
    let state: TrainingState
    let onAction: (TrainingAction) -> Void

    var body: some View {
        if let other = state.otherActiveWorkout {
            VStack(spacing: Spacing.x12) {
                Text(Strings.format("training_blocked", other))
                    .textStyle(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                Button { onAction(.onGoToActiveWorkoutTap) } label: {
                    Label { Text(Strings.format("training_go_to_workout", other)) } icon: { Image("ic_play").resizable().frame(width: 20, height: 20) }
                }
                .buttonStyle(.appSecondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            Button { onAction(.onStartTap) } label: {
                Label { Text(state.isWorkoutActive ? "training_resume" : "training_start") } icon: { Image("ic_play").resizable().frame(width: 20, height: 20) }
            }
            .buttonStyle(.appPrimary)
        }
    }
}

private extension View {
    /// A card in the list: no separator or row background, the screen's side margins.
    func cardRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: Spacing.x12 / 2, leading: Spacing.x16, bottom: Spacing.x12 / 2, trailing: Spacing.x16))
    }
}

private func previewDraft(_ id: String, _ name: String, _ icon: String, sets: Int = 4, rest: String = "90 s") -> ExerciseDraftUi {
    ExerciseDraftUi(id: id, icon: icon, name: name, subtitle: "Chest · Barbell", sets: "\(sets)", rest: rest,
                    canDecreaseSets: true, canIncreaseSets: true, canDecreaseRest: true, canIncreaseRest: true)
}

#Preview("Editing") {
    NavigationStack {
        TrainingScreen(
            state: TrainingState(isLoaded: true, name: "Push Day", icon: .dumbbell, exercises: [
                previewDraft("1", "Bench Press", "ic_ex_barbell_bench_press"),
                previewDraft("2", "Overhead Press", "ic_ex_overhead_barbell_press", sets: 3, rest: "2 min"),
            ]),
            onAction: { _ in }
        )
    }
}

#Preview("Viewing") {
    NavigationStack {
        TrainingScreen(
            state: TrainingState(isNew: false, isEditing: false, isLoaded: true, name: "Push Day", icon: .dumbbell, exercises: [
                previewDraft("1", "Bench Press", "ic_ex_barbell_bench_press"),
            ]),
            onAction: { _ in }
        )
    }
}

#Preview("Empty") {
    NavigationStack { TrainingScreen(state: TrainingState(isLoaded: true), onAction: { _ in }) }
}

import SwiftUI

struct EditWorkoutRoot: View {
    @State private var viewModel: EditWorkoutViewModel
    @State private var errorMessage: LocalizedStringResource?
    /// An exercise picked in the library, handed over by the navigation; [takePickedExercise] takes it, once.
    private let pickedExerciseId: String?
    private let takePickedExercise: () -> String?
    private let onNavigateToExerciseLibrary: () -> Void
    private let onClose: () -> Void

    init(
        viewModel: @autoclosure () -> EditWorkoutViewModel,
        pickedExerciseId: String?,
        takePickedExercise: @escaping () -> String?,
        onNavigateToExerciseLibrary: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.pickedExerciseId = pickedExerciseId
        self.takePickedExercise = takePickedExercise
        self.onNavigateToExerciseLibrary = onNavigateToExerciseLibrary
        self.onClose = onClose
    }

    var body: some View {
        EditWorkoutScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .close: onClose()
                case .navigateToExerciseLibrary: onNavigateToExerciseLibrary()
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

/// Figma "06b · Edit Workout": change the logged sets of a finished workout.
struct EditWorkoutScreen: View {
    let state: EditWorkoutState
    let onAction: (EditWorkoutAction) -> Void

    var body: some View {
        ScrollView {
            if state.isLoaded {
                LazyVStack(alignment: .leading, spacing: Spacing.x12) {
                    VStack(alignment: .leading, spacing: Spacing.x12) {
                        Text(state.title)
                            .textStyle(.largeTitle)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                            .accessibilityAddTraits(.isHeader)
                        if !state.muscles.isEmpty { MuscleChips(muscles: state.muscles) }
                    }
                    .padding(.bottom, Spacing.x12)
                    SectionLabel(
                        text: Strings.format("training_exercises_count", state.exercises.count),
                        trailing: Strings.text("workout_edit_tap_hint")
                    )
                    ForEach(state.exercises) { exercise in
                        ExerciseResultEditCard(
                            icon: exercise.icon,
                            title: exercise.name,
                            subtitle: exercise.subtitle,
                            sets: exercise.sets,
                            onSetTap: { onAction(.onSetTap(exerciseKey: exercise.key, setIndex: $0)) },
                            onAddSet: state.isFree ? { onAction(.onAddSetTap(exerciseKey: exercise.key)) } : nil,
                            onDelete: state.isFree ? { onAction(.onDeleteExerciseTap(exerciseKey: exercise.key)) } : nil
                        )
                    }
                    if state.isFree {
                        AddActionCard(title: "training_add_exercise", subtitle: "training_add_exercise_hint", action: { onAction(.onAddExerciseTap) })
                    }
                    Button { onAction(.onDeleteWorkoutTap) } label: {
                        Label { Text("workout_details_delete") } icon: { Image("ic_trash") }
                    }
                    .buttonStyle(.appDanger)
                    .padding(.top, Spacing.x12)
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.top, Spacing.x8)
                .padding(.bottom, Spacing.x40)
            }
        }
        .background(Color.bgBase)
        .navigationTitle(Text("workout_edit_title"))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden()
        // Swiping down or back would drop the edits without asking.
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action_cancel") { onAction(.onCancelTap) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action_save") { onAction(.onSaveTap) }
                    .tint(Color.accentPrimary)
                    .disabled(!state.isLoaded || !state.canSave)
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
            Text(Strings.format("workout_edit_delete_exercise_title", state.deleteExercise?.name ?? "")),
            isPresented: Binding(get: { state.deleteExercise != nil }, set: { if !$0 { onAction(.onDeleteExerciseDismiss) } }),
            actions: {
                Button("workout_edit_delete_exercise", role: .destructive) { onAction(.onDeleteExerciseConfirm) }
                Button("action_cancel", role: .cancel) { onAction(.onDeleteExerciseDismiss) }
            },
            message: { Text(Strings.plural("workout_edit_delete_exercise_message", state.deleteExercise?.setCount ?? 0)) }
        )
        .alert(
            "workout_edit_discard_title",
            isPresented: Binding(get: { state.isDiscardConfirmOpen }, set: { if !$0 { onAction(.onDiscardDismiss) } }),
            actions: {
                Button("workout_edit_discard", role: .destructive) { onAction(.onDiscardConfirm) }
                Button("workout_edit_keep_editing", role: .cancel) { onAction(.onDiscardDismiss) }
            },
            message: { Text(Strings.format("workout_edit_discard_message", state.title)) }
        )
        .confirmationDialog(
            "workout_details_delete_title",
            isPresented: Binding(get: { state.isDeleteConfirmOpen }, set: { if !$0 { onAction(.onDeleteWorkoutDismiss) } }),
            titleVisibility: .visible
        ) {
            Button("action_delete", role: .destructive) { onAction(.onDeleteWorkoutConfirm) }
            Button("action_cancel", role: .cancel) { onAction(.onDeleteWorkoutDismiss) }
        } message: {
            Text("workout_details_delete_message")
        }
    }
}

/// The muscle groups of a workout as outlined pills (Workout details and Edit workout).
struct MuscleChips: View {
    let muscles: [String]

    var body: some View {
        FlowLayout {
            ForEach(muscles, id: \.self) { muscle in
                Text(muscle)
                    .textStyle(.subhead)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.x12)
                    .padding(.vertical, Spacing.x8)
                    .background(Color.bgSurface, in: .capsule)
                    .overlay(Capsule().inset(by: 0.5).stroke(Color.borderDefault, lineWidth: 1))
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditWorkoutScreen(
            state: EditWorkoutState(
                isLoaded: true,
                title: "Free workout · Nov 1",
                muscles: ["Chest"],
                exercises: [EditExerciseUi(key: "1", icon: "ic_ex_barbell_bench_press", name: "Bench Press", subtitle: "Chest · Barbell", sets: [
                    ExerciseResultSet(number: 1, weight: "80 kg", reps: "× 10", isDone: true),
                    ExerciseResultSet(number: 2, weight: "Skipped", reps: "—", isDone: false),
                ])],
                canSave: true,
                isFree: true
            ),
            onAction: { _ in }
        )
    }
}

import SwiftUI

struct WorkoutDetailsRoot: View {
    @State private var viewModel: WorkoutDetailsViewModel
    private let onNavigateToEdit: () -> Void
    private let onClose: () -> Void

    init(viewModel: @autoclosure () -> WorkoutDetailsViewModel, onNavigateToEdit: @escaping () -> Void, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToEdit = onNavigateToEdit
        self.onClose = onClose
    }

    var body: some View {
        WorkoutDetailsScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToEdit: onNavigateToEdit()
                case .close: onClose()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

/// Figma "06 · Training Details": a finished workout's summary and every logged set.
struct WorkoutDetailsScreen: View {
    let state: WorkoutDetailsState
    let onAction: (WorkoutDetailsAction) -> Void

    var body: some View {
        ScrollView {
            if state.isLoaded {
                LazyVStack(alignment: .leading, spacing: Spacing.x12) {
                    Header(state: state)
                    VStack(spacing: Spacing.x12) {
                        HStack(spacing: Spacing.x12) {
                            Kpi(label: "workout_details_duration", stat: state.duration)
                            Kpi(label: "workout_details_volume", stat: state.volume)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.x12) {
                            Kpi(label: "workout_details_sets", stat: state.sets)
                            Kpi(label: "workout_details_records", stat: state.records)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Spacing.x8)
                    Text("workout_details_exercises")
                        .textStyle(.title2)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.top, Spacing.x8)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(state.exercises) { exercise in
                        ExerciseResultCard(
                            icon: exercise.icon,
                            title: exercise.name,
                            subtitle: exercise.subtitle,
                            isRecord: exercise.isRecord,
                            sets: exercise.sets
                        )
                    }
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.top, Spacing.x8)
                .padding(.bottom, Spacing.x40)
            }
        }
        .background(Color.bgBase)
        .inlineNavigationTitle()
        .toolbar {
            if state.isLoaded {
                ToolbarItem(placement: .primaryAction) {
                    Button { onAction(.onEditTap) } label: {
                        Label { Text("workout_edit_title") } icon: { Image("ic_pencil") }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { onAction(.onDeleteTap) } label: {
                        Label { Text("workout_details_delete") } icon: { Image("ic_trash") }
                    }
                    .tint(Color.statusDanger)
                }
            }
        }
        .confirmationDialog(
            "workout_details_delete_title",
            isPresented: Binding(get: { state.isDeleteConfirmOpen }, set: { if !$0 { onAction(.onDeleteDismiss) } }),
            titleVisibility: .visible
        ) {
            Button("action_delete", role: .destructive) { onAction(.onDeleteConfirm) }
            Button("action_cancel", role: .cancel) { onAction(.onDeleteDismiss) }
        } message: {
            Text("workout_details_delete_message")
        }
    }
}

private struct Header: View {
    let state: WorkoutDetailsState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack(spacing: Spacing.x12) {
                if let icon = state.icon { IconBadge(asset: icon) }
                Text(state.title)
                    .textStyle(.largeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(state.date).textStyle(.callout).foregroundStyle(Color.textSecondary)
            if !state.muscles.isEmpty {
                MuscleChips(muscles: state.muscles)
                .padding(.top, Spacing.x8)
            }
        }
    }
}

private struct Kpi: View {
    let label: LocalizedStringKey
    let stat: DetailsStatUi?

    var body: some View {
        StatTile(
            label: label,
            value: stat?.value ?? "",
            caption: stat?.caption ?? "",
            captionColor: stat?.isPositive == true ? .statusSuccess : .textSecondary
        )
    }
}

#Preview {
    let sets = [
        ExerciseResultSet(number: 1, weight: "80 kg", reps: "× 10", isDone: true),
        ExerciseResultSet(number: 2, weight: "90 kg", reps: "× 8", isDone: true),
        ExerciseResultSet(number: 3, weight: "100 kg", reps: "Skipped", isDone: false),
    ]
    NavigationStack {
        WorkoutDetailsScreen(
            state: WorkoutDetailsState(
                isLoaded: true,
                title: "Push Day",
                icon: "ic_dumbbell",
                date: "Mon, Sep 28 · 18:05 – 19:17",
                muscles: ["Chest", "Shoulders", "Arms"],
                duration: DetailsStatUi(value: "1h 12m", caption: "−7m vs average", isPositive: true),
                volume: DetailsStatUi(value: "12,450 kg", caption: "+4% vs last Push Day", isPositive: true),
                sets: DetailsStatUi(value: "24", caption: "Same as last"),
                records: DetailsStatUi(value: "2 PRs", caption: "Bench Press, Overhead Press", isPositive: true),
                exercises: [
                    DetailsExerciseUi(index: 0, icon: "ic_ex_barbell_bench_press", name: "Bench Press", subtitle: "3 sets · Best 90 kg × 8", isRecord: true, sets: sets),
                ]
            ),
            onAction: { _ in }
        )
    }
}

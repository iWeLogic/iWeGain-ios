import SwiftUI

struct SelectTrainingRoot: View {
    @State private var viewModel: SelectTrainingViewModel
    private let onSelected: (String) -> Void
    private let onNavigateToCreateTraining: () -> Void

    init(
        viewModel: @autoclosure () -> SelectTrainingViewModel,
        onSelected: @escaping (String) -> Void,
        onNavigateToCreateTraining: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onSelected = onSelected
        self.onNavigateToCreateTraining = onNavigateToCreateTraining
    }

    var body: some View {
        SelectTrainingScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .selected(let trainingId): onSelected(trainingId)
                case .navigateToCreateTraining: onNavigateToCreateTraining()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

/// "Select training" (Figma 31): the person's trainings to schedule, and a shortcut to create one.
struct SelectTrainingScreen: View {
    let state: SelectTrainingState
    let onAction: (SelectTrainingAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.x8) {
                AddActionCard(
                    title: "select_training_create",
                    subtitle: "select_training_create_hint",
                    action: { onAction(.onCreateTap) }
                )
                .padding(.bottom, Spacing.x12)
                SectionLabel(text: Strings.text("select_training_yours"))
                if state.isEmpty {
                    Text("select_training_empty")
                        .textStyle(.callout)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.x24)
                }
                ForEach(state.options) { option in
                    TrainingOption(
                        icon: option.icon,
                        title: option.name,
                        subtitle: option.exercises,
                        isSelected: option.id == state.selectedId,
                        action: { onAction(.onOptionTap(id: option.id)) }
                    )
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x8)
        }
        .background(Color.bgBase)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                Button { onAction(.onConfirmTap) } label: {
                    Label {
                        Text(state.selected.map { Strings.format("select_training_confirm", $0.name) } ?? Strings.text("select_training_confirm_none"))
                    } icon: {
                        Image("ic_check")
                    }
                }
                .buttonStyle(.appPrimary)
                .disabled(state.selected == nil)
                .padding(Spacing.x16)
            }
            .background(Color.bgBase)
        }
        .navigationTitle(Text("select_training_title"))
        .inlineNavigationTitle()
    }
}

#Preview {
    NavigationStack {
        SelectTrainingScreen(
            state: SelectTrainingState(
                options: [
                    TrainingOptionUi(id: "1", name: "Push Day", icon: "ic_dumbbell", exercises: "6 exercises"),
                    TrainingOptionUi(id: "2", name: "Pull Day", icon: "ic_zap", exercises: "5 exercises"),
                    TrainingOptionUi(id: "3", name: "Leg Day", icon: "ic_mountain", exercises: "5 exercises"),
                ],
                selectedId: "2",
                isLoading: false
            ),
            onAction: { _ in }
        )
    }
}

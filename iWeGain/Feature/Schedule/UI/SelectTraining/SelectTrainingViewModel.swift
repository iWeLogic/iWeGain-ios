import Foundation

/// Picks one of the selected person's trainings to schedule; [selectedTrainingId] starts selected.
final class SelectTrainingViewModel: BaseViewModel<SelectTrainingState, SelectTrainingAction, SelectTrainingEvent> {
    private let userRepository: UserRepository
    private let trainingRepository: TrainingRepository
    private var isObserving = false

    init(selectedTrainingId: String?, userRepository: UserRepository, trainingRepository: TrainingRepository) {
        self.userRepository = userRepository
        self.trainingRepository = trainingRepository
        super.init(initialState: SelectTrainingState(selectedId: selectedTrainingId))
    }

    override func onAction(_ action: SelectTrainingAction) {
        switch action {
        case .onAppear: observe()
        case .onOptionTap(let id): updateState { $0.selectedId = id }
        case .onCreateTap: sendEvent(.navigateToCreateTraining)
        case .onConfirmTap:
            if let selected = state.selected { sendEvent(.selected(trainingId: selected.id)) }
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            let trainings = userRepository.observeSelectedUserId().flatMapLatest { [trainingRepository] in
                trainingRepository.observeTrainings(userId: $0)
            }
            for await list in trainings {
                updateState { state in
                    state.options = list.map {
                        TrainingOptionUi(id: $0.id, name: $0.name, icon: $0.icon.imageName,
                                         exercises: Strings.plural("training_exercise_count", $0.exerciseCount))
                    }
                    state.isLoading = false
                }
            }
        }
    }
}

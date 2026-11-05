struct SelectTrainingState: Equatable {
    var options: [TrainingOptionUi] = []
    var selectedId: String?
    var isLoading = true

    var selected: TrainingOptionUi? { options.first { $0.id == selectedId } }
    var isEmpty: Bool { !isLoading && options.isEmpty }
}

struct TrainingOptionUi: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    /// "5 exercises".
    let exercises: String
}

enum SelectTrainingAction {
    case onAppear
    case onOptionTap(id: String)
    case onCreateTap
    case onConfirmTap
}

enum SelectTrainingEvent: UiEvent {
    case selected(trainingId: String)
    case navigateToCreateTraining
}

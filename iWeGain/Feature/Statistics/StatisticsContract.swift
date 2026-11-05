import Foundation

struct StatisticsState: Equatable {
    var users: [UserUi] = []
    /// The server couldn't be reached; shows "Offline" next to the person.
    var isOffline = false
    var period: StatsPeriod = .month
    var isLoading = true
    /// No finished workout yet: the screen shows the empty state.
    var isEmpty = false
    var workouts: KpiUi?
    var volume: KpiUi?
    var timeTrained: KpiUi?
    var records: KpiUi?
    var volumeChart: VolumeChartUi?
    var exerciseChart: ExerciseChartUi?
    /// The open chooser sheet.
    var picker: StatsPicker?
    var trainingOptions: [ChooserOptionUi] = []
    var exerciseOptions: [ChooserOptionUi] = []
}

/// One KPI tile: "Workouts · 18 · +3 vs previous month".
struct KpiUi: Equatable {
    let value: String
    let caption: String
    let trend: Trend
}

enum Trend: Equatable { case up, down, flat }

struct VolumeChartUi: Equatable {
    /// nil is "All trainings".
    let trainingId: String?
    /// "All trainings" or the chosen training's name.
    let training: String
    let bars: [BarUi]
    /// The selected bar's best workout volume: "15,200 kg".
    let value: String
    /// The selected bar's days: "Sep 28 – 30".
    let caption: String
    let barWidth: CGFloat
}

struct ExerciseChartUi: Equatable {
    let exerciseId: String
    let exerciseName: String
    let metric: ExerciseMetric
    /// Latest value in the range: "100 kg". nil when the exercise wasn't done in this period or before.
    let value: String?
    /// Change across the range: "+7.5 kg"; nil with fewer than two values.
    let delta: String?
    let trend: Trend
    let chart: LineChartUi?
}

/// A row of a chooser sheet; [id] nil is "All trainings".
struct ChooserOptionUi: Hashable {
    let id: String?
    let name: String
}

enum StatsPicker: Hashable, Identifiable {
    case training, exercise
    var id: Self { self }
}

enum StatisticsAction {
    case onAppear
    case onUserTap(id: String)
    case onCreateProfileTap
    case onInviteTap
    case onPeriodTap(StatsPeriod)
    case onBarTap(Int)
    case onTrainingChooserTap
    case onExerciseChooserTap
    case onOptionSelected(ChooserOptionUi)
    case onPickerDismiss
    case onMetricTap(ExerciseMetric)
    case onCreateTrainingTap
}

enum StatisticsEvent: UiEvent {
    case navigateToCreateProfile
    case navigateToInvite
    case navigateToNewTraining
}

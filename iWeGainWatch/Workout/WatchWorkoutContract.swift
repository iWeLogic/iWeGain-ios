import Foundation

struct WatchWorkoutUiState: Equatable {
    /// nil until the phone's last workout is read.
    var workout: WatchWorkoutState?
    var isPhoneConnected = true
    /// The Log Set screen, nil when closed.
    var logSet: WatchLogSet?
}

enum WatchWorkoutAction {
    /// "Complete": opens Log Set for the due set.
    case onCompleteTap
    case onWeightChange(steps: Int)
    case onRepsChange(delta: Int)
    case onSaveTap
    case onLogSetDismiss
    /// −15 s / +15 s next to the rest timer.
    case onAdjustRestTap(deltaSeconds: Int)
}

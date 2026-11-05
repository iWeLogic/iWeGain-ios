import Foundation
import Observation
import WatchKit

/// The only screen of the watch app: the phone's workout, and Log Set on top of it.
@Observable
final class WatchWorkoutViewModel {
    private(set) var state = WatchWorkoutUiState()

    /// The last seconds of a rest buzz once, on even numbers from 10 down.
    private static let buzzSeconds = 10

    private let link: PhoneLink
    private var isStarted = false
    @ObservationIgnored private var followedRestEnd: Date?
    @ObservationIgnored private var restTask: Task<Void, Never>?

    init(link: PhoneLink) {
        self.link = link
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        link.onWorkout = { [weak self] in self?.update($0) }
        link.onReachabilityChange = { [weak self] in self?.state.isPhoneConnected = $0 }
        link.start()
        #if DEBUG
        if DebugPhoneLink.opensLogSet { onAction(.onCompleteTap) }
        #endif
    }

    func onAction(_ action: WatchWorkoutAction) {
        switch action {
        case .onCompleteTap:
            guard state.isPhoneConnected, let workout = state.workout else { return }
            state.logSet = WatchLogSet(workout: workout)
        case .onWeightChange(let steps): state.logSet?.changeWeight(steps: steps)
        case .onRepsChange(let delta): state.logSet?.changeReps(delta: delta)
        case .onSaveTap: save()
        case .onLogSetDismiss: state.logSet = nil
        // The phone changes the rest and sends the workout back, so the timer follows in a moment.
        case .onAdjustRestTap(let deltaSeconds): Task { _ = await link.send(.adjustRest(deltaSeconds: deltaSeconds)) }
        }
    }

    private func update(_ workout: WatchWorkoutState) {
        state.workout = workout
        if state.logSet?.isOutOfDate(for: workout) == true { state.logSet = nil }
        follow(restEndingAt: workout.countingRestEnd)
    }

    private func save() {
        guard let logSet = state.logSet else { return }
        state.logSet = nil
        Task {
            // Not delivered: back to Log Set with what was entered, to try again.
            if await !link.send(logSet.command) { state.logSet = logSet }
        }
    }

    /// Buzzes through the rest while the app is on screen; the watch counts itself because the phone can
    /// only message an app that's open. Otherwise the phone's rest-over notification reaches the wrist.
    private func follow(restEndingAt end: Date?) {
        guard end != followedRestEnd else { return }
        followedRestEnd = end
        restTask?.cancel()
        guard let end else { return }
        restTask = Task {
            await RestCountdown.run(
                endsAt: end,
                now: { Date() },
                onSecond: { secondsLeft in
                    if secondsLeft <= Self.buzzSeconds, secondsLeft.isMultiple(of: 2) { WKInterfaceDevice.current().play(.click) }
                },
                onOver: { WKInterfaceDevice.current().play(.notification) }
            )
        }
    }
}

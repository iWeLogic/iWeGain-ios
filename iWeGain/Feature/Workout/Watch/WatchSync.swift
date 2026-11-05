#if os(iOS)
import Foundation
import WatchConnectivity

/// Keeps the Apple Watch app in step with the active workout, and applies the commands it sends. The phone
/// owns the workout: the watch only shows it, counts the rest down itself and logs sets through here.
///
/// Without a paired watch with the app there's nothing to do, and the session calls are skipped or fail.
final class WatchSync: NSObject, WCSessionDelegate {
    private let workoutRepository: WorkoutRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date
    private var observeTask: Task<Void, Never>?
    private var latest: WatchWorkoutState?

    init(workoutRepository: WorkoutRepository, settingsRepository: SettingsRepository, now: @escaping () -> Date) {
        self.workoutRepository = workoutRepository
        self.settingsRepository = settingsRepository
        self.now = now
    }

    func start() {
        guard observeTask == nil, WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        observeTask = Task { [weak self, workoutRepository, settingsRepository, now] in
            let states = combineLatest(workoutRepository.observeActiveWorkout(), settingsRepository.observeSettings())
                .map { workout, settings in workout.watchState(unit: settings.weightUnit, now: now()) }
                .removeDuplicates()
            for await state in states {
                guard let self else { return }
                latest = state
                publish()
            }
        }
    }

    /// The current state, right away when the watch can be reached and kept for it otherwise.
    private func publish() {
        let session = WCSession.default
        guard let latest, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let fields = latest.dictionary(sentAt: now())
        try? session.updateApplicationContext(fields)
        if session.isReachable { session.sendMessage(fields, replyHandler: nil, errorHandler: nil) }
    }

    /// Runs [command]; the state after it goes back to the watch, read here rather than from the observation,
    /// which runs a moment later.
    private func handle(_ command: WatchCommand) -> WatchWorkoutState {
        workoutRepository.perform(command)
        return workoutRepository.activeWorkout().watchState(unit: settingsRepository.settings.weightUnit, now: now())
    }

    // MARK: WCSessionDelegate (called on a background queue)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in publish() }
    }

    /// The watch app was installed, or came back in range.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in publish() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in publish() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = WatchCommand(dictionary: message) else {
            replyHandler([:])
            return
        }
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            reply(handle(command).dictionary(sentAt: now()))
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user switched to another watch: connects to it.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif

import Foundation
import WatchConnectivity

/// [PhoneLink] over WatchConnectivity. The phone sends each change over two channels, so [apply] keeps only
/// the newest; until it has sent anything, nothing is running.
final class PhoneConnection: NSObject, PhoneLink, WCSessionDelegate {
    var onWorkout: ((WatchWorkoutState) -> Void)?
    var onReachabilityChange: ((Bool) -> Void)?
    private var newestSentAt = Date.distantPast
    private var isReady = false

    func start() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ command: WatchCommand) async -> Bool {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return false }
        let update: Update?? = await withCheckedContinuation { continuation in
            session.sendMessage(
                command.dictionary,
                // @Sendable: these run on the session's queue, and without it they'd be tied to the main actor and trap.
                replyHandler: { @Sendable reply in continuation.resume(returning: .some(Update(fields: reply))) },
                errorHandler: { @Sendable _ in continuation.resume(returning: nil) }
            )
        }
        guard let update else { return false }
        if let update { apply(update) }
        return true
    }

    /// A workout state on its way from a background queue to the main actor.
    nonisolated private struct Update: Sendable {
        let workout: WatchWorkoutState
        let sentAt: Date

        init?(fields: [String: Any]) {
            guard let workout = WatchWorkoutState(dictionary: fields), let sentAt = WatchWorkoutState.sentAt(in: fields) else { return nil }
            self.workout = workout
            self.sentAt = sentAt
        }
    }

    private func apply(_ update: Update) {
        guard update.sentAt >= newestSentAt else { return }
        newestSentAt = update.sentAt
        onWorkout?(update.workout)
    }

    /// Once connected: the workout the phone last left here, then a fresh one if the phone is in reach.
    private func sessionIsReady(stored: Update?, isReachable: Bool) {
        isReady = true
        onReachabilityChange?(isReachable)
        if let stored { apply(stored) } else { onWorkout?(WatchWorkoutState(isActive: false)) }
        if isReachable { Task { _ = await send(.requestState) } }
    }

    private func reachabilityChanged(_ isReachable: Bool) {
        guard isReady else { return }
        onReachabilityChange?(isReachable)
        if isReachable { Task { _ = await send(.requestState) } }
    }

    // MARK: WCSessionDelegate (called on a background queue)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let stored = Update(fields: session.receivedApplicationContext)
        let isReachable = session.isReachable
        Task { @MainActor in sessionIsReady(stored: stored, isReachable: isReachable) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in reachabilityChanged(isReachable) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let update = Update(fields: applicationContext) else { return }
        Task { @MainActor in apply(update) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let update = Update(fields: message) else { return }
        Task { @MainActor in apply(update) }
    }
}

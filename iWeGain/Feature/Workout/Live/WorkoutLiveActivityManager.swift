#if os(iOS)
import ActivityKit
import Foundation
import OSLog
import UserNotifications

/// Keeps the workout's Live Activity in step with the active workout (Android's `WorkoutNotificationManager`):
/// shown while a workout runs, ended with it. A free workout waiting for "Start workout" has none.
///
/// The countdowns are dates the system ticks. When a rest ends while the app runs, the activity switches
/// to "Rest over"; while the app is suspended the activity goes stale at the end of the rest and shows
/// "Rest over" by itself, and the rest-over notification sounds.
final class WorkoutLiveActivityManager {
    static let restOverNotificationId = "workout-rest-over"
    private static let logger = Logger(subsystem: "com.iwelogic.gain", category: "LiveActivity")

    private let workoutRepository: WorkoutRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date

    private var observeTask: Task<Void, Never>?
    private var restEndTask: Task<Void, Never>?
    private var unit = WeightUnit.kg
    private var scheduledRestOver: (endsAt: Date, body: String)?
    private var askedForNotifications = false

    init(workoutRepository: WorkoutRepository, settingsRepository: SettingsRepository, now: @escaping () -> Date) {
        self.workoutRepository = workoutRepository
        self.settingsRepository = settingsRepository
        self.now = now
    }

    func start() {
        guard observeTask == nil else { return }
        WorkoutLiveActions.handler = { [weak self] action in await self?.perform(action) }
        observeTask = Task { [weak self, workoutRepository, settingsRepository] in
            for await (workout, settings) in combineLatest(workoutRepository.observeActiveWorkout(), settingsRepository.observeSettings()) {
                guard let self else { return }
                unit = settings.weightUnit
                await show(workout)
            }
        }
    }

    /// A button of the Live Activity. The app may be in the background, so the activity is updated right
    /// here instead of waiting for the observation.
    private func perform(_ action: WorkoutLiveActions.Action) async {
        do {
            switch action {
            case .addRest: try workoutRepository.adjustRest(deltaSeconds: ExerciseViewModel.restAdjustSeconds)
            case .skipSet: try workoutRepository.skipCurrentSet()
            case .skipRest: try workoutRepository.endRest()
            }
        } catch {
            // Nothing to show here; the activity keeps what it had.
        }
        await show(workoutRepository.activeWorkout())
    }

    private func show(_ workout: Workout?) async {
        restEndTask?.cancel()
        restEndTask = nil
        guard let workout, workout.isClockStarted else {
            updateRestOverNotification(nil)
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let state = workout.liveState(unit: unit, now: now())
        let restEnd = state.countingRest?.upperBound
        let content = ActivityContent(state: state, staleDate: restEnd)
        // Finding and requesting happen without a suspension in between, so there's never a second one.
        if Activity<WorkoutActivityAttributes>.activities.contains(where: { $0.attributes.workoutId == workout.id }) {
            await Self.update(workoutId: workout.id, with: content)
        } else {
            requestNotificationsOnce()
            // Only possible while the app is on screen, which is where workouts start.
            do {
                _ = try Activity.request(attributes: WorkoutActivityAttributes(workoutId: workout.id), content: content)
            } catch {
                Self.logger.error("Live Activity not started: \(error.localizedDescription, privacy: .public)")
            }
        }
        for other in Activity<WorkoutActivityAttributes>.activities where other.attributes.workoutId != workout.id {
            await other.end(nil, dismissalPolicy: .immediate)
        }
        updateRestOverNotification(restEnd.map { ($0, state.afterRest.text) })
        // While the app runs it switches to Rest over itself.
        if let restEnd {
            restEndTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, restEnd.timeIntervalSince(self?.now() ?? restEnd))))
                guard !Task.isCancelled, let self else { return }
                await show(workoutRepository.activeWorkout())
            }
        }
    }

    @concurrent private static func update(workoutId: String, with content: ActivityContent<WorkoutLiveState>) async {
        for activity in Activity<WorkoutActivityAttributes>.activities where activity.attributes.workoutId == workoutId {
            await activity.update(content)
        }
    }

    // MARK: Rest over notification

    private func requestNotificationsOnce() {
        guard !askedForNotifications else { return }
        askedForNotifications = true
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    /// "Rest over" at the end of a counting rest; the system shows it only while the app isn't on screen
    /// (on screen the rest timer vibrates itself).
    private func updateRestOverNotification(_ rest: (endsAt: Date, body: String)?) {
        if scheduledRestOver?.endsAt == rest?.endsAt && scheduledRestOver?.body == rest?.body { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.restOverNotificationId])
        if rest == nil { center.removeDeliveredNotifications(withIdentifiers: [Self.restOverNotificationId]) }
        scheduledRestOver = rest
        guard let rest else { return }
        let delay = rest.endsAt.timeIntervalSince(now())
        guard delay > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = Strings.text("workout_notification_rest_over")
        content.body = rest.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.restOverNotificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        center.add(request)
    }
}
#endif

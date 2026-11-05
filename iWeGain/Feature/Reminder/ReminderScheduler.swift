import Foundation
import UserNotifications

/// Keeps the system's pending notifications equal to the coming workout reminders of me (the signed-in
/// account or the guest), recalculated whenever the schedule, finished workouts or settings change.
final class ReminderScheduler {
    private static let idPrefix = "reminder."
    private static let scheduledKeysKey = "reminder_scheduled_keys"

    private let userRepository: UserRepository
    private let settingsRepository: SettingsRepository
    private let scheduleRepository: ScheduleRepository
    private let workoutRepository: WorkoutRepository
    private let trainingRepository: TrainingRepository
    private let defaults: UserDefaults
    private let now: () -> Date
    private var task: Task<Void, Never>?

    init(
        userRepository: UserRepository,
        settingsRepository: SettingsRepository,
        scheduleRepository: ScheduleRepository,
        workoutRepository: WorkoutRepository,
        trainingRepository: TrainingRepository,
        defaults: UserDefaults,
        now: @escaping () -> Date
    ) {
        self.userRepository = userRepository
        self.settingsRepository = settingsRepository
        self.scheduleRepository = scheduleRepository
        self.workoutRepository = workoutRepository
        self.trainingRepository = trainingRepository
        self.defaults = defaults
        self.now = now
    }

    /// Follows changes for the whole app run.
    func start() {
        guard task == nil else { return }
        task = Task { [self] in
            let center = UNUserNotificationCenter.current()
            // Asked at the first start, like Android; a refusal turns reminders off on this device.
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted && settingsRepository.settings.workoutReminders {
                settingsRepository.setWorkoutReminders(false, syncToAccount: false)
            }
            let inputs = userRepository.observeMeId().removeDuplicates().flatMapLatest { [settingsRepository, scheduleRepository, workoutRepository, trainingRepository] userId in
                combineLatest(
                    settingsRepository.observeSettings(),
                    scheduleRepository.observeScheduled(userId: userId),
                    workoutRepository.observeFinishedWorkouts(userId: userId),
                    trainingRepository.observeTrainings(userId: userId)
                )
            }
            for await (settings, scheduled, finished, trainings) in inputs {
                let reminders = settings.workoutReminders
                    ? Reminders.upcoming(scheduled: scheduled, finished: finished, leadMinutes: settings.reminderMinutesBefore, now: now())
                    : []
                await apply(reminders, trainings: trainings, leadMinutes: settings.reminderMinutesBefore)
            }
        }
    }

    private func apply(_ reminders: [Reminder], trainings: [Training], leadMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        // A reminder already handed to the system has been shown once its time passed; only one planned
        // too late for its time (a training in 10 minutes with a 30-minute lead) still fires right away.
        let known = Set(defaults.stringArray(forKey: Self.scheduledKeysKey) ?? [])
        let currentTime = now()
        for reminder in reminders {
            guard let training = trainings.first(where: { $0.id == reminder.occurrence.trainingId }) else { continue }
            let trigger: UNNotificationTrigger
            if reminder.at > currentTime {
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.at),
                    repeats: false
                )
            } else if known.contains(reminder.key) {
                continue
            } else {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            }
            let content = UNMutableNotificationContent()
            content.title = Strings.format("reminder_title", training.name, reminder.occurrence.startTime.formatted())
            content.body = leadMinutes == 0 ? Strings.text("reminder_starts_now") : Strings.plural("reminder_starts_in", leadMinutes)
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: Self.idPrefix + reminder.key, content: content, trigger: trigger))
        }
        defaults.set(reminders.map(\.key), forKey: Self.scheduledKeysKey)
    }

    static func isReminder(_ identifier: String) -> Bool { identifier.hasPrefix(idPrefix) }
}

/// Shows workout reminders as banners while the app is open too.
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await ReminderScheduler.isReminder(notification.request.identifier) ? [.banner, .sound] : []
    }
}

extension AppContainer {
    func makeReminderScheduler() -> ReminderScheduler {
        ReminderScheduler(
            userRepository: userRepository,
            settingsRepository: settingsRepository,
            scheduleRepository: scheduleRepository,
            workoutRepository: workoutRepository,
            trainingRepository: trainingRepository,
            defaults: defaults,
            now: store.now
        )
    }
}

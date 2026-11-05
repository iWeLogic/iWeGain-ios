import Foundation

/// A workout reminder: [occurrence] of a scheduled training, shown at [at], before its [start].
nonisolated struct Reminder: Equatable, Sendable {
    let occurrence: ScheduledTraining
    let at: Date
    let start: Date

    /// Identifies the occurrence, so one that was already shown isn't shown again.
    var key: String { "\(occurrence.id)@\(occurrence.date.epochDay)" }
}

enum Reminders {
    /// iOS can't wake the app when a reminder fires to set the next one, as Android's alarm does, so the
    /// next several are handed to the system at once. (It keeps at most 64 pending notifications.)
    static let maxPending = 30
    private static let lookaheadDays = 28

    /// The coming reminders, earliest first: [leadMinutes] before the start of each planned training that
    /// hasn't started yet. Days with a finished workout don't remind, like the calendar doesn't show them
    /// as planned. A reminder whose time just passed still counts while the training hasn't started.
    static func upcoming(
        scheduled: [ScheduledTraining],
        finished: [Workout],
        leadMinutes: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [Reminder] {
        let today = Day(now, calendar: calendar)
        let finishedByDate = Dictionary(grouping: finished) { Day($0.startedAt, calendar: calendar) }
        let reminders = scheduled.occurrences(from: today, to: today.adding(days: lookaheadDays))
            .withoutReplaced(finishedByDate: finishedByDate)
            .map { occurrence in
                let start = occurrence.date.date(at: occurrence.startTime, calendar: calendar)
                return Reminder(occurrence: occurrence, at: start.addingTimeInterval(TimeInterval(-leadMinutes * 60)), start: start)
            }
            .filter { $0.start > now }
            .sorted { $0.at < $1.at }
        return Array(reminders.prefix(maxPending))
    }
}

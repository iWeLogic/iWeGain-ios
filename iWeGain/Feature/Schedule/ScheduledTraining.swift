import Foundation

/// A training planned for a day and time on the calendar. With [repeatsWeekly] it's a series: it
/// repeats every week on [date]'s weekday from [date] on, except [skippedDates]. A single occurrence
/// edited on its own becomes a separate entry that keeps its series in [seriesId].
nonisolated struct ScheduledTraining: Identifiable, Hashable, Sendable {
    let id: String
    var userId: String
    var trainingId: String
    var date: Day
    var startTime: TimeOfDay
    var endTime: TimeOfDay
    var repeatsWeekly = false
    var seriesId: String?
    var skippedDates: Set<Day> = []
    /// When it was planned; a workout finished before then can't stand in for it. The epoch (0) for
    /// entries planned before this was recorded: any workout that day may stand in for those.
    var createdAt = Date(timeIntervalSince1970: 0)

    /// Part of a weekly series: the series itself or one occurrence edited on its own.
    var isPartOfSeries: Bool { repeatsWeekly || seriesId != nil }
}

// Rules for when scheduled trainings happen, shared by the calendar and the workout reminders.
extension [ScheduledTraining] {

    /// Every occurrence from [from] to [to], both included: single entries on their date, weekly series
    /// on their weekday every week from their first date on, except skipped dates. Occurrences keep their
    /// entry's id and carry the date they fall on. Sorted by date, then start time.
    func occurrences(from: Day, to: Day) -> [ScheduledTraining] {
        flatMap { entry -> [ScheduledTraining] in
            if !entry.repeatsWeekly {
                return entry.date >= from && entry.date <= to ? [entry] : []
            }
            var result: [ScheduledTraining] = []
            var day = entry.date < from ? from.nextOrSame(isoWeekday: entry.date.isoWeekday) : entry.date
            while day <= to {
                if !entry.skippedDates.contains(day) {
                    var occurrence = entry
                    occurrence.date = day
                    result.append(occurrence)
                }
                day = day.adding(weeks: 1)
            }
            return result
        }
        .sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
    }

    /// Drops scheduled trainings that a finished workout stands in for. The plan doesn't have to be
    /// followed exactly: any workout finished that day counts. Each workout replaces one entry of its
    /// day, preferring the same training, otherwise the earliest one. A workout only stands in for a
    /// plan that already existed when it finished, so planning more for later today keeps the new entry.
    func withoutReplaced(finishedByDate: [Day: [Workout]]) -> [ScheduledTraining] {
        let byDate = Dictionary(grouping: self, by: \.date)
        return byDate.keys.sorted().flatMap { date -> [ScheduledTraining] in
            var remaining = byDate[date]!.sorted { $0.startTime < $1.startTime }
            let workouts = finishedByDate[date] ?? []
            func canReplace(_ workout: Workout, _ entry: ScheduledTraining) -> Bool {
                entry.createdAt <= (workout.finishedAt ?? workout.startedAt)
            }
            // Same-training matches first, so a different workout doesn't take an entry its own training would match.
            let sameTraining = workouts.filter { workout in
                remaining.contains { $0.trainingId == workout.trainingId && canReplace(workout, $0) }
            }
            let others = workouts.filter { workout in !sameTraining.contains { $0.id == workout.id } }
            for workout in sameTraining {
                if let index = remaining.firstIndex(where: { $0.trainingId == workout.trainingId && canReplace(workout, $0) }) {
                    remaining.remove(at: index)
                }
            }
            for workout in others {
                if let index = remaining.firstIndex(where: { canReplace(workout, $0) }) {
                    remaining.remove(at: index)
                }
            }
            return remaining
        }
    }
}

import Foundation

/// Trainings planned on the calendar, stored in SwiftData and synced. A weekly series is one entry; its
/// occurrences are worked out when shown. Changing one occurrence on its own skips it in the series
/// and, when edited, saves it as a separate entry linked back to the series.
final class ScheduleRepository {
    private let local: ScheduleLocalDataSource
    private let now: () -> Date

    init(local: ScheduleLocalDataSource, now: @escaping () -> Date) {
        self.local = local
        self.now = now
    }

    /// Entries as stored (a series once), sorted by date, then start time.
    func observeScheduled(userId: String) -> AsyncStream<[ScheduledTraining]> {
        local.observeScheduled(userId: userId)
    }

    /// The entry as stored; for a weekly series the series itself.
    func entry(id: String) throws(DataError) -> ScheduledTraining? {
        try local.entry(id: id)
    }

    @discardableResult
    func schedule(
        userId: String,
        trainingId: String,
        date: Day,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        repeatsWeekly: Bool
    ) throws(DataError) -> ScheduledTraining {
        let entry = ScheduledTraining(
            id: UUID().uuidString.lowercased(), userId: userId, trainingId: trainingId, date: date,
            startTime: startTime, endTime: endTime, repeatsWeekly: repeatsWeekly,
            // Whole milliseconds, as stored, so the entry returned equals the one read back.
            createdAt: Date(epochMillis: now().epochMillis)
        )
        try local.save(entry)
        return entry
    }

    /// Changes the occurrence of [entryId] on [date]. With [applyToAll], every occurrence of its
    /// series gets the new training and time (dates stay). [repeatsWeekly] only applies to an entry
    /// that isn't part of a series yet, turning it into one.
    func edit(
        entryId: String,
        date: Day,
        trainingId: String,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        repeatsWeekly: Bool,
        applyToAll: Bool
    ) throws(DataError) {
        guard let entry = try local.entry(id: entryId) else { return }
        func changed(_ part: ScheduledTraining) -> ScheduledTraining {
            var copy = part
            copy.trainingId = trainingId
            copy.startTime = startTime
            copy.endTime = endTime
            return copy
        }
        if !entry.isPartOfSeries {
            var updated = changed(entry)
            updated.repeatsWeekly = repeatsWeekly
            try local.save(updated)
        } else if applyToAll {
            for part in try seriesParts(of: entry) { try local.save(changed(part)) }
        } else if entry.repeatsWeekly {
            // One occurrence of the series: skip it there and keep the edited copy on its own.
            var series = entry
            series.skippedDates.insert(date)
            try local.save(series)
            var occurrence = changed(entry)
            occurrence = ScheduledTraining(
                id: UUID().uuidString.lowercased(), userId: occurrence.userId, trainingId: occurrence.trainingId,
                date: date, startTime: occurrence.startTime, endTime: occurrence.endTime, repeatsWeekly: false,
                seriesId: entry.id, skippedDates: [], createdAt: occurrence.createdAt
            )
            try local.save(occurrence)
        } else {
            try local.save(changed(entry))
        }
    }

    /// Removes the occurrence of [entryId] on [date], or with [applyToAll] its whole series.
    func remove(entryId: String, date: Day, applyToAll: Bool) throws(DataError) {
        guard let entry = try local.entry(id: entryId) else { return }
        if applyToAll && entry.isPartOfSeries {
            for part in try seriesParts(of: entry) { try local.delete(id: part.id) }
        } else if entry.repeatsWeekly {
            // Keep the series, without this week.
            var series = entry
            series.skippedDates.insert(date)
            try local.save(series)
        } else {
            try local.delete(id: entry.id)
        }
    }

    /// The series [entry] belongs to and its occurrences edited on their own.
    private func seriesParts(of entry: ScheduledTraining) throws(DataError) -> [ScheduledTraining] {
        let series: ScheduledTraining
        if entry.repeatsWeekly {
            series = entry
        } else {
            guard let seriesId = entry.seriesId, let found = try local.entry(id: seriesId) else {
                // The series is gone already: only this entry is left.
                return [entry]
            }
            series = found
        }
        return [series] + (try local.detached(seriesId: series.id))
    }
}

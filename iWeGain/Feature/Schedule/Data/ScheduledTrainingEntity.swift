import Foundation
import SwiftData

/// Android's `scheduled_trainings` table, with the same columns.
@Model
final class ScheduledTrainingEntity {
    @Attribute(.unique) var id: String
    var userId: String
    var trainingId: String
    /// [Day.epochDay].
    var epochDay: Int
    /// [TimeOfDay.secondOfDay].
    var startSecond: Int
    var endSecond: Int
    /// Repeats every week; see [ScheduledTraining.repeatsWeekly].
    var repeatsWeekly: Bool
    /// The series an occurrence edited on its own came from.
    var seriesId: String?
    /// Occurrences of a weekly series that were removed or edited on their own: comma-separated epoch days.
    var skippedDays: String
    /// Removed; kept as a tombstone so the removal reaches other devices.
    var isDeleted: Bool
    /// Epoch millis; see [ScheduledTraining.createdAt].
    var createdAt: Int64
    /// Epoch millis of the last change, made here or on another device; the newer copy wins when syncing.
    var updatedAt: Int64
    /// Changed on this device and not uploaded to Firestore yet.
    var isDirty: Bool

    init(entry: ScheduledTraining, updatedAt: Int64) {
        id = entry.id
        userId = entry.userId
        trainingId = entry.trainingId
        epochDay = entry.date.epochDay
        startSecond = entry.startTime.secondOfDay
        endSecond = entry.endTime.secondOfDay
        repeatsWeekly = entry.repeatsWeekly
        seriesId = entry.seriesId
        skippedDays = Self.skippedDaysText(entry.skippedDates)
        isDeleted = false
        createdAt = entry.createdAt.epochMillis
        self.updatedAt = updatedAt
        isDirty = true
    }

    /// Copies [entry]'s fields into this row and queues it for upload.
    func update(from entry: ScheduledTraining, updatedAt: Int64) {
        userId = entry.userId
        trainingId = entry.trainingId
        epochDay = entry.date.epochDay
        startSecond = entry.startTime.secondOfDay
        endSecond = entry.endTime.secondOfDay
        repeatsWeekly = entry.repeatsWeekly
        seriesId = entry.seriesId
        skippedDays = Self.skippedDaysText(entry.skippedDates)
        createdAt = entry.createdAt.epochMillis
        self.updatedAt = updatedAt
        isDirty = true
    }

    func toScheduledTraining() -> ScheduledTraining {
        ScheduledTraining(
            id: id,
            userId: userId,
            trainingId: trainingId,
            date: Day(epochDay: epochDay),
            startTime: TimeOfDay(secondOfDay: startSecond),
            endTime: TimeOfDay(secondOfDay: endSecond),
            repeatsWeekly: repeatsWeekly,
            seriesId: seriesId,
            skippedDates: Set(skippedDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map(Day.init(epochDay:))),
            createdAt: Date(epochMillis: createdAt)
        )
    }

    static func skippedDaysText(_ days: Set<Day>) -> String {
        days.map(\.epochDay).sorted().map(String.init).joined(separator: ",")
    }
}

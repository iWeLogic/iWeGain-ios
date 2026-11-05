import Foundation
import SwiftData

/// Scheduled trainings ⇄ `users/{uid}/scheduledTrainings`.
final class ScheduleSyncDataSource: BaseDataSource, SyncTable {
    let name = "scheduledTrainings"
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    func dirtyRows(uid: String) throws -> [SyncUpload] {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(predicate: #Predicate { $0.userId == uid && $0.isDirty }))
            .map { SyncUpload(id: $0.id, updatedAt: $0.updatedAt, fields: Self.document($0)) }
    }

    static func document(_ row: ScheduledTrainingEntity) -> [String: Any] {
        [
            "userId": row.userId,
            "trainingId": row.trainingId,
            "epochDay": row.epochDay,
            "startSecond": row.startSecond,
            "endSecond": row.endSecond,
            "repeatsWeekly": row.repeatsWeekly,
            "seriesId": orNull(row.seriesId),
            // A list of numbers in Firestore, comma-separated text in the database (like Android).
            "skippedDays": row.skippedDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) },
            "deleted": row.isDeleted,
            "createdAt": row.createdAt,
            "updatedAt": row.updatedAt,
        ]
    }

    func applyRemote(id: String, fields: [String: Any], uid: String) throws {
        guard let trainingId = fields.string("trainingId"), let epochDay = fields.int("epochDay"),
              let startSecond = fields.int("startSecond"), let endSecond = fields.int("endSecond") else { return }
        let updatedAt = fields.int64("updatedAt") ?? 0
        let existing = try row(id: id)
        if let existing, updatedAt <= existing.updatedAt { return }
        let skipped = (fields["skippedDays"] as? [NSNumber] ?? []).map { Day(epochDay: $0.intValue) }
        let entry = ScheduledTraining(
            id: id, userId: uid, trainingId: trainingId, date: Day(epochDay: epochDay),
            startTime: TimeOfDay(secondOfDay: startSecond), endTime: TimeOfDay(secondOfDay: endSecond),
            repeatsWeekly: fields.bool("repeatsWeekly") ?? false, seriesId: fields.string("seriesId"),
            skippedDates: Set(skipped), createdAt: Date(epochMillis: fields.int64("createdAt") ?? 0)
        )
        let row = existing ?? {
            let new = ScheduledTrainingEntity(entry: entry, updatedAt: updatedAt)
            store.context.insert(new)
            return new
        }()
        row.update(from: entry, updatedAt: updatedAt)
        row.isDeleted = fields.bool("deleted") ?? false
        row.isDirty = false
    }

    func markClean(id: String, updatedAt: Int64) throws {
        if let row = try row(id: id), row.updatedAt == updatedAt { row.isDirty = false }
    }

    func reassign(from: String, to: String) throws {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(predicate: #Predicate { $0.userId == from })).forEach {
            $0.userId = to
            $0.isDirty = true
        }
    }

    func deleteRows(uid: String) throws {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(predicate: #Predicate { $0.userId == uid })).forEach { store.context.delete($0) }
    }

    func deleteAll() throws {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>()).forEach { store.context.delete($0) }
    }

    private func row(id: String) throws -> ScheduledTrainingEntity? {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

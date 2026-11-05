import Foundation
import SwiftData

final class ScheduleLocalDataSource: BaseDataSource {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    /// Entries as stored (a series once), sorted by date, then start time.
    func observeScheduled(userId: String) -> AsyncStream<[ScheduledTraining]> {
        observe(store) { [store] in
            try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(
                predicate: #Predicate { $0.userId == userId && !$0.isDeleted },
                sortBy: [SortDescriptor(\.epochDay), SortDescriptor(\.startSecond)]
            )).map { $0.toScheduledTraining() }
        }
    }

    func entry(id: String) throws(DataError) -> ScheduledTraining? {
        try dbRequest { try entity(id: id).flatMap { $0.isDeleted ? nil : $0.toScheduledTraining() } }
    }

    /// Occurrences of the weekly series [seriesId] that were edited on their own.
    func detached(seriesId: String) throws(DataError) -> [ScheduledTraining] {
        try dbRequest {
            try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(
                predicate: #Predicate { $0.seriesId == seriesId && !$0.isDeleted }
            )).map { $0.toScheduledTraining() }
        }
    }

    func save(_ entry: ScheduledTraining) throws(DataError) {
        try dbRequest {
            let now = store.now().epochMillis
            if let existing = try entity(id: entry.id) {
                existing.update(from: entry, updatedAt: now)
                existing.isDeleted = false
            } else {
                store.context.insert(ScheduledTrainingEntity(entry: entry, updatedAt: now))
            }
            try store.save()
        }
    }

    /// Keeps a tombstone, so the removal is synced to other devices.
    func delete(id: String) throws(DataError) {
        try dbRequest {
            guard let entity = try entity(id: id) else { return }
            markDeleted(entity)
            try store.save()
        }
    }

    /// Removes every planned session of [trainingId], e.g. when the training is deleted.
    func deleteForTraining(trainingId: String) throws(DataError) {
        try dbRequest {
            try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(
                predicate: #Predicate { $0.trainingId == trainingId && !$0.isDeleted }
            )).forEach(markDeleted)
            try store.save()
        }
    }

    private func markDeleted(_ entity: ScheduledTrainingEntity) {
        entity.isDeleted = true
        entity.updatedAt = store.now().epochMillis
        entity.isDirty = true
    }

    private func entity(id: String) throws -> ScheduledTrainingEntity? {
        try store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

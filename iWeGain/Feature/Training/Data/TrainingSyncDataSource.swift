import Foundation
import SwiftData

/// Trainings ⇄ `users/{uid}/trainings`. Each document holds its exercises.
final class TrainingSyncDataSource: BaseDataSource, SyncTable {
    let name = "trainings"
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    func dirtyRows(uid: String) throws -> [SyncUpload] {
        try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { $0.userId == uid && $0.isDirty }))
            .map { SyncUpload(id: $0.id, updatedAt: $0.updatedAt, fields: Self.document($0)) }
    }

    static func document(_ row: TrainingEntity) -> [String: Any] {
        [
            "userId": row.userId,
            "name": row.name,
            "icon": row.icon,
            "createdAt": row.createdAt,
            "deleted": row.isDeleted,
            "updatedAt": row.updatedAt,
            "exercises": row.exercises.sorted { $0.position < $1.position }.map {
                ["exerciseId": $0.exerciseId, "sets": $0.sets, "restSeconds": $0.restSeconds] as [String: Any]
            },
        ]
    }

    func applyRemote(id: String, fields: [String: Any], uid: String) throws {
        guard let name = fields.string("name"), let icon = fields.string("icon") else { return }
        let updatedAt = fields.int64("updatedAt") ?? 0
        let row: TrainingEntity
        if let existing = try self.row(id: id) {
            guard updatedAt > existing.updatedAt else { return }
            row = existing
            row.exercises.forEach { store.context.delete($0) }
            row.exercises = []
        } else {
            row = TrainingEntity(id: id, userId: uid, name: name, icon: icon, createdAt: 0, updatedAt: updatedAt, isDirty: false)
            store.context.insert(row)
        }
        row.userId = uid
        row.name = name
        row.icon = icon
        row.createdAt = fields.int64("createdAt") ?? 0
        row.isDeleted = fields.bool("deleted") ?? false
        row.updatedAt = updatedAt
        row.isDirty = false
        row.exercises = fields.maps("exercises").enumerated().compactMap { position, entry in
            guard let exerciseId = entry.string("exerciseId"), let sets = entry.int("sets") else { return nil }
            return TrainingExerciseEntity(position: position, exerciseId: exerciseId, sets: sets, restSeconds: entry.int("restSeconds") ?? 0)
        }
    }

    func markClean(id: String, updatedAt: Int64) throws {
        if let row = try row(id: id), row.updatedAt == updatedAt { row.isDirty = false }
    }

    func reassign(from: String, to: String) throws {
        try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { $0.userId == from })).forEach {
            $0.userId = to
            $0.isDirty = true
        }
    }

    func deleteRows(uid: String) throws {
        try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { $0.userId == uid })).forEach { store.context.delete($0) }
    }

    func deleteAll() throws {
        try store.context.fetch(FetchDescriptor<TrainingEntity>()).forEach { store.context.delete($0) }
    }

    private func row(id: String) throws -> TrainingEntity? {
        try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

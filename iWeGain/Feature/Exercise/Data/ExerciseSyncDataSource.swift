import Foundation
import SwiftData

/// Custom exercises ⇄ `users/{uid}/customExercises`.
final class ExerciseSyncDataSource: BaseDataSource, SyncTable {
    let name = "customExercises"
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    func dirtyRows(uid: String) throws -> [SyncUpload] {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.userId == uid && $0.isDirty }))
            .map { SyncUpload(id: $0.id, updatedAt: $0.updatedAt, fields: Self.document($0)) }
    }

    static func document(_ row: CustomExerciseEntity) -> [String: Any] {
        ["name": row.name, "muscleGroup": row.muscleGroup, "equipment": row.equipment, "icon": row.icon, "updatedAt": row.updatedAt]
    }

    func applyRemote(id: String, fields: [String: Any], uid: String) throws {
        guard let name = fields.string("name"),
              let muscleGroup = fields.string("muscleGroup"), MuscleGroup(rawValue: muscleGroup) != nil,
              let equipment = fields.string("equipment"), Equipment(rawValue: equipment) != nil,
              let icon = fields.string("icon") else { return }
        let updatedAt = fields.int64("updatedAt") ?? 0
        if let row = try row(id: id) {
            guard updatedAt > row.updatedAt else { return }
            row.userId = uid
            row.name = name
            row.muscleGroup = muscleGroup
            row.equipment = equipment
            row.icon = icon
            row.updatedAt = updatedAt
            row.isDirty = false
        } else {
            store.context.insert(CustomExerciseEntity(id: id, userId: uid, name: name, muscleGroup: muscleGroup, equipment: equipment, icon: icon, updatedAt: updatedAt, isDirty: false))
        }
    }

    func markClean(id: String, updatedAt: Int64) throws {
        if let row = try row(id: id), row.updatedAt == updatedAt { row.isDirty = false }
    }

    func reassign(from: String, to: String) throws {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.userId == from })).forEach {
            $0.userId = to
            $0.isDirty = true
        }
    }

    func deleteRows(uid: String) throws {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.userId == uid })).forEach { store.context.delete($0) }
    }

    func deleteAll() throws {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>()).forEach { store.context.delete($0) }
    }

    private func row(id: String) throws -> CustomExerciseEntity? {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

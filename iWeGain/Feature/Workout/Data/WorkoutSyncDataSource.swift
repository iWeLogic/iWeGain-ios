import Foundation
import SwiftData

/// Workouts (the one in progress and finished ones) ⇄ `users/{uid}/workouts`. Each document holds the
/// exercises, and each exercise its sets.
final class WorkoutSyncDataSource: BaseDataSource, SyncTable {
    let name = "workouts"
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    func dirtyRows(uid: String) throws -> [SyncUpload] {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.userId == uid && $0.isDirty }))
            .map { SyncUpload(id: $0.id, updatedAt: $0.updatedAt, fields: Self.document($0)) }
    }

    static func document(_ row: WorkoutEntity) -> [String: Any] {
        [
            "userId": row.userId,
            "trainingId": row.trainingId,
            "trainingName": row.trainingName,
            "trainingIcon": row.trainingIcon,
            "startedAt": row.startedAt,
            "finishedAt": orNull(row.finishedAt),
            "restEndsAt": orNull(row.restEndsAt),
            "restDurationSeconds": orNull(row.restDurationSeconds),
            "restExerciseIndex": orNull(row.restExerciseIndex),
            "restSetIndex": orNull(row.restSetIndex),
            "restPausedAt": orNull(row.restPausedAt),
            "setsDoneAt": orNull(row.setsDoneAt),
            "deleted": row.isDeleted,
            "updatedAt": row.updatedAt,
            "exercises": row.exercises.sorted { $0.position < $1.position }.map { exercise -> [String: Any] in
                [
                    "exerciseId": exercise.exerciseId,
                    "name": exercise.name,
                    "muscleGroup": exercise.muscleGroup,
                    "equipment": exercise.equipment,
                    "icon": exercise.icon,
                    "isCustom": exercise.isCustom,
                    "restSeconds": exercise.restSeconds,
                    "isSkipped": exercise.isSkipped,
                    "startedAt": orNull(exercise.startedAt),
                    "sets": exercise.sets.sorted { $0.position < $1.position }.map { set -> [String: Any] in
                        [
                            "status": set.status,
                            "targetWeightKg": set.targetWeightKg,
                            "targetReps": set.targetReps,
                            "weightKg": orNull(set.weightKg),
                            "reps": orNull(set.reps),
                        ]
                    },
                ]
            },
        ]
    }

    func applyRemote(id: String, fields: [String: Any], uid: String) throws {
        guard let trainingId = fields.string("trainingId"), let trainingName = fields.string("trainingName"),
              let trainingIcon = fields.string("trainingIcon"), let startedAt = fields.int64("startedAt"),
              let exercises = Self.exercises(fields) else { return }
        let updatedAt = fields.int64("updatedAt") ?? 0
        let row: WorkoutEntity
        if let existing = try self.row(id: id) {
            guard updatedAt > existing.updatedAt else { return }
            row = existing
            row.exercises.forEach { store.context.delete($0) }
            row.exercises = []
        } else {
            row = WorkoutEntity(id: id, userId: uid, updatedAt: updatedAt)
            store.context.insert(row)
        }
        row.userId = uid
        row.trainingId = trainingId
        row.trainingName = trainingName
        row.trainingIcon = trainingIcon
        row.startedAt = startedAt
        row.finishedAt = fields.int64("finishedAt")
        row.restEndsAt = fields.int64("restEndsAt")
        row.restDurationSeconds = fields.int("restDurationSeconds")
        row.restExerciseIndex = fields.int("restExerciseIndex")
        row.restSetIndex = fields.int("restSetIndex")
        row.restPausedAt = fields.int64("restPausedAt")
        row.setsDoneAt = fields.int64("setsDoneAt")
        row.isDeleted = fields.bool("deleted") ?? false
        row.updatedAt = updatedAt
        row.isDirty = false
        row.exercises = exercises
    }

    /// nil when the document can't be read: it's skipped whole, like on Android.
    private static func exercises(_ fields: [String: Any]) -> [WorkoutExerciseEntity]? {
        var result: [WorkoutExerciseEntity] = []
        for (position, map) in fields.maps("exercises").enumerated() {
            guard let exerciseId = map.string("exerciseId"), let name = map.string("name"),
                  let muscle = map.string("muscleGroup").flatMap(MuscleGroup.init(rawValue:)),
                  let equipment = map.string("equipment").flatMap(Equipment.init(rawValue:)),
                  let icon = map.string("icon") else { return nil }
            var sets: [WorkoutSet] = []
            for set in map.maps("sets") {
                guard let status = set.string("status").flatMap(SetStatus.init(rawValue:)) else { return nil }
                sets.append(WorkoutSet(status: status, targetWeightKg: set.double("targetWeightKg") ?? 0, targetReps: set.int("targetReps") ?? 0, weightKg: set.double("weightKg"), reps: set.int("reps")))
            }
            result.append(WorkoutExerciseEntity(position: position, exercise: WorkoutExercise(
                exercise: Exercise(id: exerciseId, name: name, muscleGroup: muscle, equipment: equipment, icon: ItemIcon(storedValue: icon), isCustom: map.bool("isCustom") ?? false),
                restSeconds: map.int("restSeconds") ?? 0,
                sets: sets,
                isSkipped: map.bool("isSkipped") ?? false,
                startedAt: map.int64("startedAt").map(Date.init(epochMillis:))
            )))
        }
        return result
    }

    func markClean(id: String, updatedAt: Int64) throws {
        if let row = try row(id: id), row.updatedAt == updatedAt { row.isDirty = false }
    }

    func reassign(from: String, to: String) throws {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.userId == from })).forEach {
            $0.userId = to
            $0.isDirty = true
        }
    }

    func deleteRows(uid: String) throws {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.userId == uid })).forEach { store.context.delete($0) }
    }

    func deleteAll() throws {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>()).forEach { store.context.delete($0) }
    }

    private func row(id: String) throws -> WorkoutEntity? {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.id == id })).first
    }
}

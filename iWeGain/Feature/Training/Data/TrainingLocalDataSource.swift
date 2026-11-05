import Foundation
import SwiftData

/// Trainings store exercise ids; the caller passes the current exercise library to resolve them,
/// so edits to custom exercises show up in every training.
final class TrainingLocalDataSource: BaseDataSource {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    /// [userId]'s trainings in the order they were created.
    func observeTrainings(userId: String, library: @escaping () throws -> [Exercise]) -> AsyncStream<[Training]> {
        observe(store) { [store] in
            let byId = Self.index(try library())
            return try store.context.fetch(FetchDescriptor<TrainingEntity>(
                predicate: #Predicate { $0.userId == userId && !$0.isDeleted },
                sortBy: [SortDescriptor(\.createdAt)]
            )).map { $0.toTraining(library: byId) }
        }
    }

    func training(id: String, library: [Exercise]) throws(DataError) -> Training? {
        try dbRequest { try entity(id: id).flatMap { $0.isDeleted ? nil : $0.toTraining(library: Self.index(library)) } }
    }

    /// Everyone's trainings.
    func allTrainings(library: [Exercise]) throws(DataError) -> [Training] {
        try dbRequest {
            let byId = Self.index(library)
            return try store.context.fetch(FetchDescriptor<TrainingEntity>(
                predicate: #Predicate { !$0.isDeleted },
                sortBy: [SortDescriptor(\.createdAt)]
            )).map { $0.toTraining(library: byId) }
        }
    }

    /// Inserts a new training or replaces an existing one, keeping its place in the list.
    func save(_ training: Training) throws(DataError) {
        try dbRequest {
            let now = store.now().epochMillis
            let row: TrainingEntity
            if let existing = try entity(id: training.id) {
                row = existing
                row.exercises.forEach { store.context.delete($0) }
                row.exercises = []
            } else {
                row = TrainingEntity(id: training.id, userId: training.userId, name: training.name, icon: training.icon.rawValue, createdAt: now, updatedAt: now)
                store.context.insert(row)
            }
            row.userId = training.userId
            row.name = training.name
            row.icon = training.icon.rawValue
            row.isDeleted = false
            row.updatedAt = now
            row.isDirty = true
            row.exercises = training.exercises.enumerated().map { position, entry in
                TrainingExerciseEntity(position: position, exerciseId: entry.exercise.id, sets: entry.sets, restSeconds: entry.restSeconds)
            }
            try store.save()
        }
    }

    /// Leaves a tombstone that syncs; the exercise list goes now.
    func delete(id: String) throws(DataError) {
        try dbRequest {
            guard let entity = try entity(id: id) else { return }
            entity.exercises.forEach { store.context.delete($0) }
            entity.exercises = []
            entity.isDeleted = true
            entity.updatedAt = store.now().epochMillis
            entity.isDirty = true
            try store.save()
        }
    }

    private func entity(id: String) throws -> TrainingEntity? {
        try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private static func index(_ library: [Exercise]) -> [String: Exercise] {
        Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

import Foundation
import SwiftData

/// Custom exercises in SwiftData.
final class ExerciseLocalDataSource: BaseDataSource {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    /// [userId]'s custom exercises sorted by name, or everyone's when nil.
    func observeCustomExercises(userId: String?) -> AsyncStream<[Exercise]> {
        observe(store) { [store] in try Self.fetch(userId: userId, in: store.context) }
    }

    func customExercises(userId: String?) throws(DataError) -> [Exercise] {
        try dbRequest { try Self.fetch(userId: userId, in: store.context) }
    }

    func customExercise(id: String) throws(DataError) -> Exercise? {
        try dbRequest { try entity(id: id)?.toExercise() }
    }

    func save(_ exercise: Exercise) throws(DataError) {
        try dbRequest {
            guard let userId = exercise.userId else { preconditionFailure("Only custom exercises are stored") }
            let now = store.now().epochMillis
            if let existing = try entity(id: exercise.id) {
                existing.update(from: exercise, updatedAt: now)
            } else {
                store.context.insert(CustomExerciseEntity(
                    id: exercise.id, userId: userId, name: exercise.name, muscleGroup: exercise.muscleGroup.rawValue,
                    equipment: exercise.equipment.rawValue, icon: exercise.icon.rawValue, updatedAt: now
                ))
            }
            try store.save()
        }
    }

    private func entity(id: String) throws -> CustomExerciseEntity? {
        try store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private static func fetch(userId: String?, in context: ModelContext) throws -> [Exercise] {
        let descriptor = userId.map { id in FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.userId == id }) }
            ?? FetchDescriptor<CustomExerciseEntity>()
        return try context.fetch(descriptor)
            .map { $0.toExercise() }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

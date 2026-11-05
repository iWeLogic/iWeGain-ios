import Foundation
import SwiftData

final class WorkoutLocalDataSource: BaseDataSource {
    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    /// A person has at most one running workout; another person can have their own at the same time.
    func observeActiveWorkout(userId: String) -> AsyncStream<Workout?> {
        observe(store) { [self] in try activeEntity(userId: userId).map(localized) }
    }

    /// Newest first.
    func observeFinishedWorkouts(userId: String) -> AsyncStream<[Workout]> {
        observe(store) { [self] in
            let titles = try trainingTitles()
            return try store.context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.userId == userId && $0.finishedAt != nil && !$0.isDeleted },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )).map { localized($0, titles: titles) }
        }
    }

    func observeWorkout(id: String) -> AsyncStream<Workout?> {
        observe(store) { [self] in
            guard let entity = try entity(id: id), !entity.isDeleted else { return nil }
            return try localized(entity)
        }
    }

    func activeWorkout(userId: String) throws(DataError) -> Workout? {
        try dbRequest { try activeEntity(userId: userId).map(localized) }
    }

    /// A workout as stored, with the names it was saved with (not localized), for writing it back.
    func storedWorkout(id: String) throws(DataError) -> Workout? {
        try dbRequest { try entity(id: id).flatMap { $0.isDeleted ? nil : $0.toWorkout() } }
    }

    /// Saves the workout and replaces its exercises and sets.
    func save(_ workout: Workout) throws(DataError) {
        try dbRequest {
            let row: WorkoutEntity
            if let existing = try entity(id: workout.id) {
                row = existing
            } else {
                row = WorkoutEntity(id: workout.id, userId: workout.userId, updatedAt: 0)
                store.context.insert(row)
            }
            row.isDeleted = false
            row.update(from: workout, updatedAt: store.now().epochMillis, context: store.context)
            try store.save()
        }
    }

    /// Leaves a tombstone that syncs; the exercises and sets go now.
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

    /// The completed sets of [exerciseId] in [userId]'s latest finished workout that has any.
    func lastHistory(userId: String, exerciseId: String) throws(DataError) -> ExerciseHistory? {
        try dbRequest {
            let finished = try store.context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.userId == userId && $0.finishedAt != nil && !$0.isDeleted },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            ))
            for workout in finished {
                let sets = workout.exercises
                    .filter { $0.exerciseId == exerciseId }
                    .sorted { $0.position < $1.position }
                    .flatMap { exercise in exercise.sets.sorted { $0.position < $1.position } }
                    .map { $0.toWorkoutSet() }
                    .filter { $0.status == .done }
                if !sets.isEmpty { return ExerciseHistory(date: Date(epochMillis: workout.startedAt), sets: sets) }
            }
            return nil
        }
    }

    private func activeEntity(userId: String) throws -> WorkoutEntity? {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.userId == userId && $0.finishedAt == nil && !$0.isDeleted },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try store.context.fetch(descriptor).first
    }

    private func entity(id: String) throws -> WorkoutEntity? {
        try store.context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.id == id })).first
    }

    /// Current name and icon of every training that still exists, so workouts can follow renames.
    private func trainingTitles() throws -> [String: (name: String, icon: ItemIcon)] {
        let trainings = try store.context.fetch(FetchDescriptor<TrainingEntity>(predicate: #Predicate { !$0.isDeleted }))
        return Dictionary(trainings.map { ($0.id, (name: $0.name, icon: ItemIcon(storedValue: $0.icon))) }, uniquingKeysWith: { first, _ in first })
    }

    private func localized(_ entity: WorkoutEntity) throws -> Workout {
        localized(entity, titles: try trainingTitles())
    }

    /// Workouts store the training's and each exercise's name as they were when they started. The
    /// training's current name and icon are shown instead while it exists, so history follows edits;
    /// built-in exercises show their current name and picture, so history follows the app language.
    private func localized(_ entity: WorkoutEntity, titles: [String: (name: String, icon: ItemIcon)]) -> Workout {
        var workout = entity.toWorkout()
        if let trainingId = workout.trainingId, let title = titles[trainingId] {
            workout.trainingName = title.name
            workout.trainingIcon = title.icon
        }
        workout.exercises = workout.exercises.map { entry in
            guard !entry.exercise.isCustom, let current = BuiltInExercises.exercise(id: entry.exercise.id) else { return entry }
            var updated = entry
            updated.exercise.name = current.name
            updated.exercise.builtInImage = current.builtInImage
            return updated
        }
        return workout
    }
}

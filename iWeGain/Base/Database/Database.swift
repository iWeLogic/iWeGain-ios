import SwiftData

/// The app's SwiftData store. Every @Model type is listed in [schema]. Until the first App Store release
/// the schema changes freely; from then on each change freezes a `VersionedSchema` and adds a migration stage.
enum Database {
    static let schema = Schema([
        CustomExerciseEntity.self,
        TrainingEntity.self,
        TrainingExerciseEntity.self,
        ScheduledTrainingEntity.self,
        WorkoutEntity.self,
        WorkoutExerciseEntity.self,
        WorkoutSetEntity.self,
        SyncCursorEntity.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

import Foundation
import SwiftData
import Testing
@testable import iWeGain

@MainActor
struct ExerciseRepositoryTests {
    private let container = AppContainer.inMemory(now: { Date(epochMillis: 1_000) })
    private var repository: ExerciseRepository { container.exerciseRepository }

    @Test func builtInLibraryMatchesAndroid() {
        let library = BuiltInExercises.library()
        #expect(library.count == 88)
        #expect(Set(library.map(\.id)).count == library.count)
        let squat = BuiltInExercises.exercise(id: "back_squat")
        #expect(squat?.muscleGroup == .legs)
        #expect(squat?.equipment == .barbell)
        #expect(squat?.imageName == "ic_ex_barbell_squat")
        #expect(squat?.isCustom == false)
        // Names come from the String Catalog, not the key.
        #expect(squat?.name == "Barbell Squat")
    }

    @Test func customExercisesBelongToTheirPerson() async throws {
        let mine = try repository.createExercise(userId: "me", name: "zercher squat", muscleGroup: .legs, equipment: .barbell, icon: .mountain)
        _ = try repository.createExercise(userId: "me", name: "Arm wrestling", muscleGroup: .arms, equipment: .bodyweight, icon: .trophy)
        _ = try repository.createExercise(userId: "someone", name: "Theirs", muscleGroup: .core, equipment: .cable, icon: .star)

        let forMe = try #require(await repository.observeExercises(userId: "me").first())
        // Built-in first, then my own sorted by name ignoring case.
        #expect(Array(forMe.dropFirst(88)).map(\.name) == ["Arm wrestling", "zercher squat"])
        #expect(repository.exercise(id: mine.id)?.userId == "me")
        #expect(repository.exercise(id: "bench_press")?.isCustom == false)
        #expect(repository.exercise(id: "missing") == nil)
        #expect(try repository.allExercises().count == 91)
    }

    @Test func savedExercisesAreQueuedForUpload() throws {
        let exercise = try repository.createExercise(userId: "me", name: "Sled", muscleGroup: .legs, equipment: .machine, icon: .bike)
        let id = exercise.id
        let row = try #require(try container.store.context.fetch(FetchDescriptor<CustomExerciseEntity>(predicate: #Predicate { $0.id == id })).first)
        #expect(row.isDirty)
        #expect(row.updatedAt == 1_000)
        #expect(row.icon == "Bike")
    }
}

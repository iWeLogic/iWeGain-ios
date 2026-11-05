import Foundation
import SwiftData
import Testing
@testable import iWeGain

@MainActor
struct TrainingRepositoryTests {
    private let container = AppContainer.inMemory()
    private var repository: TrainingRepository { container.trainingRepository }

    private func training(id: String = "t1", name: String = "Push day", exercises: [TrainingExercise]) -> Training {
        Training(id: id, userId: "user", name: name, icon: .flame, exercises: exercises)
    }

    private var bench: Exercise { BuiltInExercises.exercise(id: "bench_press")! }

    @Test func savedTrainingComesBackWithItsExercisesInOrder() throws {
        let custom = try container.exerciseRepository.createExercise(userId: "user", name: "Sled push", muscleGroup: .legs, equipment: .machine, icon: .bike)
        try repository.saveTraining(training(exercises: [
            TrainingExercise(exercise: custom, sets: 3, restSeconds: 90),
            TrainingExercise(exercise: bench, sets: 5, restSeconds: 180),
        ]))

        let saved = try #require(try repository.training(id: "t1"))
        #expect(saved.name == "Push day")
        #expect(saved.icon == .flame)
        #expect(saved.exercises.map(\.exercise.id) == [custom.id, "bench_press"])
        #expect(saved.setCount == 8)
    }

    @Test func savingAgainReplacesTheExercisesAndKeepsTheOrderOfTrainings() throws {
        try repository.saveTraining(training(id: "a", name: "A", exercises: [TrainingExercise(exercise: bench, sets: 3, restSeconds: 60)]))
        try repository.saveTraining(training(id: "b", name: "B", exercises: []))
        try repository.saveTraining(training(id: "a", name: "A2", exercises: []))

        #expect(try repository.allTrainings().map(\.name) == ["A2", "B"])
        #expect(try repository.training(id: "a")?.exercises.isEmpty == true)
        #expect(try container.store.context.fetchCount(FetchDescriptor<TrainingExerciseEntity>()) == 0)
    }

    @Test func customExerciseEditsShowUpInTrainings() throws {
        var custom = try container.exerciseRepository.createExercise(userId: "user", name: "Sled push", muscleGroup: .legs, equipment: .machine, icon: .bike)
        try repository.saveTraining(training(exercises: [TrainingExercise(exercise: custom, sets: 3, restSeconds: 90)]))
        custom.name = "Prowler push"
        try container.exerciseRepository.updateExercise(custom)

        #expect(try repository.training(id: "t1")?.exercises.first?.exercise.name == "Prowler push")
    }

    @Test func deletingLeavesASyncedTombstoneAndRemovesPlannedSessions() throws {
        try repository.saveTraining(training(exercises: [TrainingExercise(exercise: bench, sets: 3, restSeconds: 60)]))
        try container.scheduleRepository.schedule(
            userId: "user", trainingId: "t1", date: Day(year: 2026, month: 11, day: 2),
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        )

        try repository.deleteTraining(id: "t1")

        #expect(try repository.training(id: "t1") == nil)
        let row = try #require(try container.store.context.fetch(FetchDescriptor<TrainingEntity>()).first)
        #expect(row.isDeleted && row.isDirty && row.exercises.isEmpty)
        #expect(try container.store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>()).allSatisfy(\.isDeleted))
    }

    @Test func observedTrainingsFollowChangesForTheirUserOnly() async throws {
        var stream = repository.observeTrainings(userId: "user").makeAsyncIterator()
        #expect(await stream.next() == [])
        try repository.saveTraining(Training(id: "other", userId: "someone", name: "X", icon: .star, exercises: []))
        try repository.saveTraining(training(exercises: []))
        #expect(await stream.next()?.map(\.id) == ["t1"])
    }
}

import Foundation
import Testing
@testable import iWeGain

/// The Firestore documents the sync tables read and write, which Android reads and writes too.
@MainActor
struct SyncTablesTests {
    private let container = AppContainer.inMemory(now: { Date(epochMillis: 1_000) })
    private var store: LocalStore { container.store }

    private func customExercise(_ uid: String) -> Exercise? {
        (try? container.exerciseRepository.allExercises())?.first { $0.isCustom && $0.userId == uid }
    }

    @Test func exerciseAppliesOnlyANewerServerCopy() throws {
        let table = ExerciseSyncDataSource(store: store)
        func fields(name: String, updatedAt: Int64) -> [String: Any] {
            ["name": name, "muscleGroup": MuscleGroup.fullBody.rawValue, "equipment": Equipment.bodyweight.rawValue, "icon": ItemIcon.dumbbell.rawValue, "updatedAt": NSNumber(value: updatedAt)]
        }
        try table.applyRemote(id: "e1", fields: fields(name: "First", updatedAt: 10), uid: "u")
        try store.save()
        try table.applyRemote(id: "e1", fields: fields(name: "Older", updatedAt: 5), uid: "u")
        try store.save()
        #expect(customExercise("u")?.name == "First")
        try table.applyRemote(id: "e1", fields: fields(name: "Newer", updatedAt: 20), uid: "u")
        try store.save()
        #expect(customExercise("u")?.name == "Newer")
        #expect(try table.dirtyRows(uid: "u").isEmpty)
    }

    @Test func aDocumentThatCantBeReadIsSkipped() throws {
        let table = ExerciseSyncDataSource(store: store)
        try table.applyRemote(id: "e1", fields: ["name": "No group"], uid: "u")
        try store.save()
        #expect(customExercise("u") == nil)
    }

    @Test func aSavedTrainingBecomesADirtyDocumentAndCleanOnceUploaded() throws {
        let bench = try #require(BuiltInExercises.exercise(id: "bench_press"))
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: "u", name: "Push", icon: .dumbbell, exercises: [TrainingExercise(exercise: bench, sets: 4, restSeconds: 90)]))
        let table = TrainingSyncDataSource(store: store)
        let row = try #require(try table.dirtyRows(uid: "u").first)
        #expect(row.id == "t1")
        #expect(row.fields["name"] as? String == "Push")
        #expect(row.fields["deleted"] as? Bool == false)
        let exercises = try #require(row.fields["exercises"] as? [[String: Any]])
        #expect(exercises.first?["exerciseId"] as? String == "bench_press")
        #expect(exercises.first?["sets"] as? Int == 4)

        try table.markClean(id: "t1", updatedAt: row.updatedAt - 1)
        try store.save()
        #expect(try table.dirtyRows(uid: "u").count == 1, "changed again while uploading")
        try table.markClean(id: "t1", updatedAt: row.updatedAt)
        try store.save()
        #expect(try table.dirtyRows(uid: "u").isEmpty)
    }

    @Test func scheduleRoundTripsThroughItsDocument() throws {
        let table = ScheduleSyncDataSource(store: store)
        let fields: [String: Any] = [
            "trainingId": "t1", "epochDay": NSNumber(value: 20_000), "startSecond": NSNumber(value: 64_800), "endSecond": NSNumber(value: 68_400),
            "repeatsWeekly": NSNumber(value: true), "seriesId": NSNull(), "skippedDays": [NSNumber(value: 20_007), NSNumber(value: 20_014)],
            "deleted": NSNumber(value: false), "createdAt": NSNumber(value: 5 as Int64), "updatedAt": NSNumber(value: 50 as Int64),
        ]
        try table.applyRemote(id: "s1", fields: fields, uid: "u")
        try store.save()
        let entry = try #require(try container.scheduleRepository.entry(id: "s1"))
        #expect(entry.date == Day(epochDay: 20_000))
        #expect(entry.skippedDates == [Day(epochDay: 20_007), Day(epochDay: 20_014)])
        #expect(entry.seriesId == nil)
        #expect(try table.dirtyRows(uid: "u").isEmpty)
    }

    @Test func workoutDocumentKeepsAFreeWorkoutsEmptyTrainingIdAndNulls() throws {
        let table = WorkoutSyncDataSource(store: store)
        let set: [String: Any] = ["status": SetStatus.done.rawValue, "targetWeightKg": NSNumber(value: 60.0), "targetReps": NSNumber(value: 8), "weightKg": NSNumber(value: 62.5), "reps": NSNumber(value: 8)]
        let exercise: [String: Any] = [
            "exerciseId": "bench_press", "name": "Bench", "muscleGroup": MuscleGroup.fullBody.rawValue, "equipment": Equipment.bodyweight.rawValue,
            "icon": ItemIcon.dumbbell.rawValue, "isCustom": NSNumber(value: false), "restSeconds": NSNumber(value: 90), "isSkipped": NSNumber(value: false),
            "startedAt": NSNull(), "sets": [set],
        ]
        let fields: [String: Any] = [
            "userId": "u", "trainingId": "", "trainingName": "Free", "trainingIcon": ItemIcon.dumbbell.rawValue,
            "startedAt": NSNumber(value: 1_000 as Int64), "finishedAt": NSNumber(value: 2_000 as Int64), "restEndsAt": NSNull(), "deleted": NSNumber(value: false),
            "updatedAt": NSNumber(value: 7 as Int64), "exercises": [exercise],
        ]
        try table.applyRemote(id: "w1", fields: fields, uid: "u")
        try store.save()
        let workout = try #require(try container.workoutRepository.storedWorkout(id: "w1"))
        #expect(workout.trainingId == nil)
        #expect(workout.exercises.first?.sets.first?.weightKg == 62.5)
        #expect(workout.rest == nil)
        #expect(try table.dirtyRows(uid: "u").isEmpty)
    }

    @Test func guestDataGoesToTheAccountAndIsQueuedForUpload() throws {
        let bench = try #require(BuiltInExercises.exercise(id: "bench_press"))
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: User.guestId, name: "Push", icon: .dumbbell, exercises: [TrainingExercise(exercise: bench, sets: 1, restSeconds: 60)]))
        try container.deviceDataSource.claimGuestData(uid: "me")
        #expect(try TrainingSyncDataSource(store: store).dirtyRows(uid: "me").map(\.id) == ["t1"])
        #expect(try TrainingSyncDataSource(store: store).dirtyRows(uid: User.guestId).isEmpty)
    }

    @Test func clearingTheDeviceRemovesEverything() throws {
        let bench = try #require(BuiltInExercises.exercise(id: "bench_press"))
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: "me", name: "Push", icon: .dumbbell, exercises: [TrainingExercise(exercise: bench, sets: 1, restSeconds: 60)]))
        try container.syncCursors.advance(uid: "me", collection: "trainings", newest: .init(seconds: 1, nanoseconds: 0))
        try container.deviceDataSource.clearDatabase()
        #expect(try container.trainingRepository.allTrainings().isEmpty)
        #expect(container.syncCursors.get(uid: "me", collection: "trainings") == nil)
    }

    @Test func aCursorOnlyMovesForward() throws {
        let cursors = container.syncCursors
        try cursors.advance(uid: "u", collection: "c", newest: .init(seconds: 10, nanoseconds: 5))
        try cursors.advance(uid: "u", collection: "c", newest: .init(seconds: 9, nanoseconds: 9))
        try store.save()
        #expect(cursors.get(uid: "u", collection: "c") == .init(seconds: 10, nanoseconds: 5))
    }
}

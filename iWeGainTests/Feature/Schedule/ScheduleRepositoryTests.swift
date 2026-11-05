import Foundation
import SwiftData
import Testing
@testable import iWeGain

/// Android: ScheduleRepositoryTest, over a real in-memory SwiftData store.
@MainActor
struct ScheduleRepositoryTests {
    private let container = AppContainer.inMemory()
    private var repository: ScheduleRepository { container.scheduleRepository }

    // A Thursday.
    private let start = Day(year: 2026, month: 10, day: 1)
    private var nextWeek: Day { start.adding(weeks: 1) }
    private let six = TimeOfDay(hour: 18, minute: 0)
    private let seven = TimeOfDay(hour: 19, minute: 0)
    private let eight = TimeOfDay(hour: 20, minute: 0)

    private func series() throws -> String {
        try repository.schedule(userId: "user", trainingId: "legs", date: start, startTime: six, endTime: seven, repeatsWeekly: true).id
    }

    private func rows() throws -> [ScheduledTrainingEntity] {
        try container.store.context.fetch(FetchDescriptor<ScheduledTrainingEntity>())
    }

    private func alive() throws -> [ScheduledTrainingEntity] { try rows().filter { !$0.isDeleted } }

    private func row(_ id: String) throws -> ScheduledTrainingEntity { try #require(try rows().first { $0.id == id }) }

    @Test func editingOneOccurrenceSkipsItInTheSeriesAndSavesItSeparately() throws {
        let id = try series()
        try repository.edit(entryId: id, date: nextWeek, trainingId: "push", startTime: seven, endTime: eight, repeatsWeekly: true, applyToAll: false)

        let seriesRow = try row(id)
        #expect(seriesRow.trainingId == "legs")
        #expect(seriesRow.skippedDays == "\(nextWeek.epochDay)")
        let detached = try #require(try alive().first { $0.id != id })
        #expect(try alive().count == 2)
        #expect(detached.seriesId == id)
        #expect(detached.epochDay == nextWeek.epochDay)
        #expect(detached.trainingId == "push")
        #expect(detached.repeatsWeekly == false)
    }

    @Test func deletingATrainingRemovesAllItsPlannedSessionsAndKeepsOthers() throws {
        let id = try series()
        try repository.edit(entryId: id, date: nextWeek, trainingId: "legs", startTime: seven, endTime: eight, repeatsWeekly: true, applyToAll: false)
        try repository.schedule(userId: "user", trainingId: "push", date: start, startTime: seven, endTime: eight, repeatsWeekly: false)

        try ScheduleLocalDataSource(store: container.store).deleteForTraining(trainingId: "legs")

        #expect(try alive().map(\.trainingId) == ["push"])
        // Tombstones are queued for upload, so other devices drop them too.
        #expect(try rows().filter { $0.trainingId == "legs" }.allSatisfy { $0.isDeleted && $0.isDirty })
    }

    @Test func editingWithApplyToAllChangesTheSeriesAndItsDetachedOccurrences() throws {
        let id = try series()
        try repository.edit(entryId: id, date: nextWeek, trainingId: "push", startTime: seven, endTime: eight, repeatsWeekly: true, applyToAll: false)
        let detachedId = try #require(try alive().first { $0.id != id }).id

        try repository.edit(entryId: detachedId, date: nextWeek, trainingId: "back", startTime: six, endTime: eight, repeatsWeekly: false, applyToAll: true)

        #expect(try alive().allSatisfy { $0.trainingId == "back" && $0.endSecond == eight.secondOfDay })
        // Dates stay where they were.
        #expect(try row(id).epochDay == start.epochDay)
        #expect(try row(detachedId).epochDay == nextWeek.epochDay)
    }

    @Test func removingOneOccurrenceKeepsTheRestOfTheSeries() throws {
        let id = try series()
        try repository.remove(entryId: id, date: nextWeek, applyToAll: false)

        let seriesRow = try row(id)
        #expect(seriesRow.isDeleted == false)
        #expect(seriesRow.skippedDays == "\(nextWeek.epochDay)")
    }

    @Test func removingWithApplyToAllRemovesTheWholeSeries() throws {
        let id = try series()
        try repository.edit(entryId: id, date: nextWeek, trainingId: "push", startTime: seven, endTime: eight, repeatsWeekly: true, applyToAll: false)
        try repository.remove(entryId: id, date: start, applyToAll: true)

        #expect(try alive().isEmpty)
    }

    @Test func editingASingleEntryCanMakeItRepeat() throws {
        let id = try repository.schedule(userId: "user", trainingId: "legs", date: start, startTime: six, endTime: seven, repeatsWeekly: false).id
        try repository.edit(entryId: id, date: start, trainingId: "legs", startTime: six, endTime: seven, repeatsWeekly: true, applyToAll: false)

        #expect(try row(id).repeatsWeekly == true)
    }

    @Test func observedEntriesFollowChanges() async throws {
        var stream = repository.observeScheduled(userId: "user").makeAsyncIterator()
        #expect(await stream.next() == [])
        let entry = try repository.schedule(userId: "user", trainingId: "legs", date: start, startTime: six, endTime: seven, repeatsWeekly: false)
        #expect(await stream.next() == [entry])
    }
}

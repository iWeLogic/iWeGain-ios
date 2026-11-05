import Foundation
import Testing
@testable import iWeGain

/// Android: ScheduleOccurrencesTest and ScheduleMatchingTest.
struct ScheduledTrainingTests {

    // A Thursday.
    private let start = Day(year: 2026, month: 10, day: 1)

    private func entry(date: Day? = nil, repeats: Bool = false, skipped: Set<Day> = []) -> ScheduledTraining {
        ScheduledTraining(
            id: "s1", userId: "user", trainingId: "legs", date: date ?? start,
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0),
            repeatsWeekly: repeats, skippedDates: skipped
        )
    }

    private func scheduled(_ id: String, _ trainingId: String, hour: Int = 18, createdAt: Int64 = 0) -> ScheduledTraining {
        ScheduledTraining(
            id: id, userId: "user", trainingId: trainingId, date: start,
            startTime: TimeOfDay(hour: hour, minute: 0), endTime: TimeOfDay(hour: hour + 1, minute: 0),
            createdAt: Date(epochMillis: createdAt)
        )
    }

    private func workout(_ trainingId: String) -> Workout {
        Workout(
            id: "w-\(trainingId)", userId: "user", trainingId: trainingId, trainingName: trainingId, trainingIcon: .dumbbell,
            startedAt: Date(epochMillis: 0), finishedAt: Date(epochMillis: 1), exercises: []
        )
    }

    // Occurrences

    @Test func singleEntryAppearsOnlyOnItsDate() {
        let result = [entry()].occurrences(from: start.adding(days: -3), to: start.adding(days: 30))
        #expect(result.map(\.date) == [start])
    }

    @Test func weeklySeriesRepeatsOnItsWeekdayFromItsFirstDate() {
        let result = [entry(repeats: true)].occurrences(from: Day(year: 2026, month: 9, day: 1), to: Day(year: 2026, month: 10, day: 31))
        #expect(result.map(\.date) == [1, 8, 15, 22, 29].map { Day(year: 2026, month: 10, day: $0) })
    }

    @Test func weeklySeriesStartedBeforeTheRangeContinuesInIt() {
        let result = [entry(repeats: true)].occurrences(from: Day(year: 2027, month: 3, day: 1), to: Day(year: 2027, month: 3, day: 14))
        #expect(result.map(\.date) == [Day(year: 2027, month: 3, day: 4), Day(year: 2027, month: 3, day: 11)])
    }

    @Test func skippedWeeksAreLeftOut() {
        let result = [entry(repeats: true, skipped: [start.adding(weeks: 1)])].occurrences(from: start, to: start.adding(weeks: 2))
        #expect(result.map(\.date) == [start, start.adding(weeks: 2)])
    }

    @Test func occurrencesKeepTheSeriesId() {
        let result = [entry(repeats: true)].occurrences(from: start, to: start.adding(weeks: 1))
        #expect(result.map(\.id) == ["s1", "s1"])
    }

    // Matching finished workouts

    @Test func missedTrainingIsReplacedByAnotherTrainingDoneThatDay() {
        #expect([scheduled("s1", "legs")].withoutReplaced(finishedByDate: [start: [workout("push")]]).isEmpty)
    }

    @Test func trainingPlannedAfterTheWorkoutFinishedIsNotReplaced() {
        // Planned for later today after already training today: the new plan stays.
        let entry = scheduled("s1", "legs", createdAt: 10)
        #expect([entry].withoutReplaced(finishedByDate: [start: [workout("legs")]]) == [entry])
    }

    @Test func trainingPlannedBeforeTheWorkoutFinishedIsReplaced() {
        let entry = scheduled("s1", "legs", createdAt: 1)
        #expect([entry].withoutReplaced(finishedByDate: [start: [workout("legs")]]).isEmpty)
    }

    @Test func workoutSkipsAPlanMadeAfterItAndReplacesAnOlderOne() {
        let old = scheduled("s1", "legs", hour: 9)
        let new = scheduled("s2", "push", hour: 7, createdAt: 10)
        #expect([old, new].withoutReplaced(finishedByDate: [start: [workout("pull")]]) == [new])
    }

    @Test func scheduledTrainingStaysWhenNothingWasDone() {
        let entry = scheduled("s1", "legs")
        #expect([entry].withoutReplaced(finishedByDate: [:]) == [entry])
    }

    @Test func workoutOnAnotherDayDoesNotReplace() {
        let entry = scheduled("s1", "legs")
        #expect([entry].withoutReplaced(finishedByDate: [start.adding(days: 1): [workout("legs")]]) == [entry])
    }

    @Test func eachWorkoutReplacesOneEntryPreferringTheSameTraining() {
        let legs = scheduled("s1", "legs", hour: 9)
        let push = scheduled("s2", "push", hour: 18)
        #expect([legs, push].withoutReplaced(finishedByDate: [start: [workout("push")]]) == [legs])
    }

    @Test func differentWorkoutDoesNotTakeAnEntryAnotherWorkoutMatches() {
        let legs = scheduled("s1", "legs", hour: 9)
        let push = scheduled("s2", "push", hour: 18)
        // Arms (no entry) then legs: legs takes its own entry, arms takes the remaining push entry.
        #expect([legs, push].withoutReplaced(finishedByDate: [start: [workout("arms"), workout("legs")]]).isEmpty)
    }
}

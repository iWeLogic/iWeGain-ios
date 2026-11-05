import Foundation
import Testing
@testable import iWeGain

struct StatisticsMathTests {
    private let today = Day(year: 2026, month: 3, day: 31)
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func monthRangeRollsFromTheDayAfterTheSameDateAMonthAgo() {
        // March 31 → Feb 28 (shorter month) + 1 day.
        #expect(StatisticsMath.range(.month, today: today) == StatsSlot(start: Day(year: 2026, month: 3, day: 1), end: today))
    }

    @Test func yearRangeStartsOnTheFirstOfTheMonthElevenMonthsAgo() {
        #expect(StatisticsMath.range(.year, today: today).start == Day(year: 2025, month: 4, day: 1))
        #expect(StatisticsMath.barSlots(.year, today: Day(year: 2026, month: 3, day: 15)).last?.end == Day(year: 2026, month: 3, day: 15))
        #expect(StatisticsMath.barSlots(.year, today: today).count == 12)
    }

    @Test func monthBarsAreTenCountedBackFromToday() {
        let slots = StatisticsMath.barSlots(.month, today: today)
        #expect(slots.count == 10)
        #expect(slots.last == StatsSlot(start: Day(year: 2026, month: 3, day: 29), end: today))
        #expect(slots.first?.start == StatisticsMath.range(.month, today: today).start)
    }

    @Test func gridLinesContainTheValues() {
        #expect(StatisticsMath.gridLines([92.5, 100]) == [100, 95, 90])
        #expect(StatisticsMath.gridLines([100]) == [105, 100, 95])
    }

    @Test func carryPreviousOnlyFillsAnEmptyFirstSlot() {
        #expect(StatisticsMath.carryPrevious([nil, 5], previous: 3) == [3, 5])
        #expect(StatisticsMath.carryPrevious([4, 5], previous: 3) == [4, 5])
        #expect(StatisticsMath.carryPrevious([nil, 5], previous: nil) == [nil, 5])
    }

    @Test func aRecordMustBeatAnEarlierWorkout() {
        let bench = BuiltInExercises.exercise(id: "bench_press")!
        func workout(_ day: Day, _ kg: Double) -> Workout {
            Workout(
                id: "\(day.epochDay)", userId: "u", trainingId: nil, trainingName: "", trainingIcon: .dumbbell,
                startedAt: day.date(at: TimeOfDay(hour: 10, minute: 0), calendar: utc),
                finishedAt: day.date(at: TimeOfDay(hour: 11, minute: 0), calendar: utc),
                exercises: [WorkoutExercise(exercise: bench, restSeconds: 90, sets: [WorkoutSet(status: .done, targetWeightKg: kg, targetReps: 5, weightKg: kg, reps: 5)])]
            )
        }
        let range = StatisticsMath.range(.week, today: today)
        #expect(StatisticsMath.personalRecords([workout(today, 100)], range: range, calendar: utc) == 0)
        #expect(StatisticsMath.personalRecords([workout(today, 100), workout(today.adding(days: -30), 90)], range: range, calendar: utc) == 1)
        #expect(StatisticsMath.personalRecords([workout(today, 90), workout(today.adding(days: -30), 100)], range: range, calendar: utc) == 0)
    }
}

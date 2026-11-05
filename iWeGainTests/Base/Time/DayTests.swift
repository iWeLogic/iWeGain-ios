import Foundation
import Testing
@testable import iWeGain

struct DayTests {

    @Test func epochDayMatchesJavaLocalDate() {
        #expect(Day(year: 1970, month: 1, day: 1).epochDay == 0)
        // LocalDate.of(2026, 10, 1).toEpochDay() == 20727
        #expect(Day(year: 2026, month: 10, day: 1).epochDay == 20727)
        #expect(Day(year: 1969, month: 12, day: 31).epochDay == -1)
        let day = Day(epochDay: 20727)
        #expect((day.year, day.month, day.day) == (2026, 10, 1))
    }

    @Test func weekdayIsIso() {
        #expect(Day(year: 2026, month: 10, day: 1).isoWeekday == 4)   // Thursday
        #expect(Day(year: 2026, month: 10, day: 4).isoWeekday == 7)   // Sunday
        #expect(Day(year: 2026, month: 10, day: 5).isoWeekday == 1)   // Monday
        #expect(Day(year: 1969, month: 12, day: 29).isoWeekday == 1)  // before the epoch
    }

    @Test func addingMonthsClampsToTheMonthsLength() {
        #expect(Day(year: 2026, month: 1, day: 31).adding(months: 1) == Day(year: 2026, month: 2, day: 28))
        #expect(Day(year: 2028, month: 1, day: 31).adding(months: 1) == Day(year: 2028, month: 2, day: 29))
        #expect(Day(year: 2026, month: 11, day: 15).adding(months: -11) == Day(year: 2025, month: 12, day: 15))
        #expect(Day(year: 2026, month: 3, day: 31).adding(months: -1) == Day(year: 2026, month: 2, day: 28))
    }

    @Test func nextAndPreviousWeekday() {
        let thursday = Day(year: 2026, month: 10, day: 1)
        #expect(thursday.nextOrSame(isoWeekday: 4) == thursday)
        #expect(thursday.nextOrSame(isoWeekday: 1) == Day(year: 2026, month: 10, day: 5))
        #expect(thursday.previousOrSame(isoWeekday: 7) == Day(year: 2026, month: 9, day: 27))
    }

    @Test func convertsToAndFromDatesInTheCalendarsTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv")!
        let day = Day(year: 2026, month: 10, day: 25)
        let evening = day.date(at: TimeOfDay(hour: 23, minute: 30), calendar: calendar)
        #expect(Day(evening, calendar: calendar) == day)
        #expect(TimeOfDay(evening, calendar: calendar) == TimeOfDay(hour: 23, minute: 30))
        #expect(Day(day.startDate(calendar: calendar), calendar: calendar) == day)
    }

    @Test func epochMillisRoundTrip() {
        #expect(Date(epochMillis: 1_790_000_000_123).epochMillis == 1_790_000_000_123)
        #expect(Workout.notStarted.epochMillis == -1)
    }
}

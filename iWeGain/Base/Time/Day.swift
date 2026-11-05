import Foundation

/// A calendar date without a time or time zone (Java's `LocalDate`). Stored as [epochDay], days since
/// 1970-01-01, which is also how Android stores it, so synced data means the same date on both.
nonisolated struct Day: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let epochDay: Int

    init(epochDay: Int) {
        self.epochDay = epochDay
    }

    init(year: Int, month: Int, day: Int) {
        // Days from civil (Howard Hinnant's algorithm), proleptic Gregorian.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        epochDay = era * 146_097 + dayOfEra - 719_468
    }

    /// The day [date] falls on in [calendar]'s time zone.
    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    static func today(calendar: Calendar = .current, now: Date = .now) -> Day { Day(now, calendar: calendar) }

    var year: Int { civil.year }
    var month: Int { civil.month }
    var day: Int { civil.day }

    /// ISO weekday: Monday is 1, Sunday is 7.
    var isoWeekday: Int {
        let offset = (epochDay + 3) % 7  // 1970-01-01 was a Thursday.
        return (offset < 0 ? offset + 7 : offset) + 1
    }

    var lengthOfMonth: Int {
        switch month {
        case 2: Self.isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    func adding(days: Int) -> Day { Day(epochDay: epochDay + days) }
    func adding(weeks: Int) -> Day { adding(days: weeks * 7) }

    /// The same day of the month [months] later, or the month's last day when it's shorter (Jan 31 + 1 → Feb 28).
    func adding(months: Int) -> Day {
        let total = year * 12 + (month - 1) + months
        let newYear = total >= 0 ? total / 12 : (total - 11) / 12
        let newMonth = total - newYear * 12 + 1
        let first = Day(year: newYear, month: newMonth, day: 1)
        return Day(year: newYear, month: newMonth, day: min(day, first.lengthOfMonth))
    }

    func adding(years: Int) -> Day { adding(months: years * 12) }

    /// The first day of this day's month.
    var startOfMonth: Day { Day(year: year, month: month, day: 1) }

    /// The next day (this one included) that falls on [isoWeekday].
    func nextOrSame(isoWeekday target: Int) -> Day { adding(days: (target - isoWeekday + 7) % 7) }

    /// The previous day (this one included) that falls on [isoWeekday].
    func previousOrSame(isoWeekday target: Int) -> Day { adding(days: -((isoWeekday - target + 7) % 7)) }

    /// Midnight at the start of this day in [calendar]'s time zone.
    func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// This day at [time] in [calendar]'s time zone.
    func date(at time: TimeOfDay, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: time.hour, minute: time.minute, second: time.second))!
    }

    static func < (lhs: Day, rhs: Day) -> Bool { lhs.epochDay < rhs.epochDay }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    private var civil: (year: Int, month: Int, day: Int) {
        // Civil from days (Howard Hinnant's algorithm).
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    private static func isLeap(_ year: Int) -> Bool { (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 }
}

nonisolated extension Day {
    /// The ISO weekday (Monday 1 … Sunday 7) weeks start on in [calendar]'s locale.
    static func firstIsoWeekday(calendar: Calendar = .current) -> Int {
        calendar.firstWeekday == 1 ? 7 : calendar.firstWeekday - 1
    }

    /// Midday of this day: a [Date] for formatting the date that no time zone shift moves to another day.
    var middayDate: Date { date(at: TimeOfDay(hour: 12, minute: 0)) }

    /// "Wed, Sep 30" in the device's language.
    var shortTitle: String { middayDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }

    /// "Thursday" in the device's language.
    var weekdayName: String { middayDate.formatted(.dateTime.weekday(.wide)) }

    /// "September 2026" in the device's language, starting with a capital letter.
    var monthTitle: String {
        let title = middayDate.formatted(.dateTime.month(.wide).year())
        return title.prefix(1).capitalized + title.dropFirst()
    }
}

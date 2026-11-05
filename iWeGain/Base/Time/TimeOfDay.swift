import Foundation

/// A time of day without a date (Java's `LocalTime`), stored as seconds since midnight like Android does.
nonisolated struct TimeOfDay: Hashable, Comparable, Codable, Sendable {
    let secondOfDay: Int

    init(secondOfDay: Int) {
        self.secondOfDay = secondOfDay
    }

    init(hour: Int, minute: Int, second: Int = 0) {
        secondOfDay = hour * 3600 + minute * 60 + second
    }

    /// The time [date] shows in [calendar]'s time zone.
    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        self.init(hour: components.hour!, minute: components.minute!, second: components.second!)
    }

    var hour: Int { secondOfDay / 3600 }
    var minute: Int { secondOfDay % 3600 / 60 }
    var second: Int { secondOfDay % 60 }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.secondOfDay < rhs.secondOfDay }
}

nonisolated extension TimeOfDay {
    /// This time [seconds] later, wrapping past midnight like `LocalTime.plusSeconds`.
    func adding(seconds: Int) -> TimeOfDay {
        TimeOfDay(secondOfDay: ((secondOfDay + seconds) % 86_400 + 86_400) % 86_400)
    }

    /// "18:00" or "6:00 PM", following the device's 12/24-hour setting.
    func formatted(calendar: Calendar = .current) -> String {
        Day(epochDay: 0).date(at: self, calendar: calendar).formatted(date: .omitted, time: .shortened)
    }

    /// This time on today's date, for a time picker.
    func pickerDate(calendar: Calendar = .current) -> Date { Day.today(calendar: calendar).date(at: self, calendar: calendar) }
}

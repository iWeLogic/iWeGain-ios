import Foundation
import Testing
@testable import iWeGain

@MainActor
struct ReminderTests {
    private let day = Day(year: 2026, month: 3, day: 10)

    private func entry(_ id: String, _ date: Day, repeats: Bool = false) -> ScheduledTraining {
        ScheduledTraining(id: id, userId: "u", trainingId: "t", date: date, startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: repeats)
    }

    @Test func comesBeforeTheStartAndSkipsWhatAlreadyStarted() {
        let now = day.date(at: TimeOfDay(hour: 18, minute: 30))
        let reminders = Reminders.upcoming(scheduled: [entry("past", day), entry("next", day.adding(days: 1))], finished: [], leadMinutes: 30, now: now)
        #expect(reminders.map(\.occurrence.id) == ["next"])
        #expect(reminders[0].at == day.adding(days: 1).date(at: TimeOfDay(hour: 17, minute: 30)))
    }

    @Test func aPassedReminderTimeStillCountsUntilTheTrainingStarts() {
        let now = day.date(at: TimeOfDay(hour: 17, minute: 50))
        #expect(Reminders.upcoming(scheduled: [entry("soon", day)], finished: [], leadMinutes: 30, now: now).count == 1)
    }

    @Test func weeklySeriesGiveSeveralRemindersUpToTheLimit() {
        let now = day.date(at: TimeOfDay(hour: 8, minute: 0))
        let reminders = Reminders.upcoming(scheduled: [entry("weekly", day, repeats: true)], finished: [], leadMinutes: 0, now: now)
        #expect(reminders.count == 5)
        #expect(Set(reminders.map(\.key)).count == 5)
    }
}

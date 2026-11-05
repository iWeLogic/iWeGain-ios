import Foundation

nonisolated enum StatsPeriod: CaseIterable, Equatable, Sendable { case week, month, year }

/// What the exercise chart plots: the volume (weight × reps) of its biggest [set], or its [maximum] set weight.
nonisolated enum ExerciseMetric: CaseIterable, Equatable, Sendable { case set, maximum }

/// A span of days in a chart, both ends included.
nonisolated struct StatsSlot: Equatable, Sendable {
    let start: Day
    let end: Day

    func contains(_ date: Day) -> Bool { date >= start && date <= end }
}

/// Pure calculations behind the Statistics screen, the same as Android's `StatisticsMath`.
nonisolated enum StatisticsMath {
    private static let monthBars = 10
    private static let daysPerMonthBar = 3

    /// The days a period covers, ending with [today]. The windows roll instead of following the calendar:
    /// a week is the last 7 days, a month runs from the day after the same date a month ago (28 to 31 days),
    /// and a year covers the last 12 months, starting on the first day of the month 11 months ago.
    static func range(_ period: StatsPeriod, today: Day) -> StatsSlot {
        switch period {
        case .week: StatsSlot(start: today.adding(days: -6), end: today)
        case .month: StatsSlot(start: today.adding(months: -1).adding(days: 1), end: today)
        case .year: StatsSlot(start: today.startOfMonth.adding(months: -11), end: today)
        }
    }

    /// Bars of the volume chart: one per day for a week, one per month for a year (the last ends today), and
    /// 10 bars for a month. Counted back from today, nine bars take 3 days each and the first the remaining 1 to 4.
    static func barSlots(_ period: StatsPeriod, today: Day) -> [StatsSlot] {
        let range = range(period, today: today)
        switch period {
        case .week: return days(range)
        case .month:
            return (0..<monthBars).map { index in
                let end = today.adding(days: -(monthBars - 1 - index) * daysPerMonthBar)
                return StatsSlot(start: index == 0 ? range.start : end.adding(days: -(daysPerMonthBar - 1)), end: end)
            }
        case .year: return months(range)
        }
    }

    /// Points of the exercise chart: one per day for a week or month, one per month for a year.
    static func lineSlots(_ period: StatsPeriod, today: Day) -> [StatsSlot] {
        let range = range(period, today: today)
        return period == .year ? months(range) : days(range)
    }

    /// The window of the same length just before the period, for "vs previous 7 days" comparisons.
    static func previousPeriod(_ period: StatsPeriod, today: Day) -> StatsSlot {
        switch period {
        case .week:
            let end = today.adding(weeks: -1)
            return StatsSlot(start: end.adding(days: -6), end: end)
        case .month:
            let end = today.adding(months: -1)
            return StatsSlot(start: end.adding(months: -1).adding(days: 1), end: end)
        case .year:
            let start = range(period, today: today).start
            return StatsSlot(start: start.adding(years: -1), end: start.adding(days: -1))
        }
    }

    /// Volume of each bar, in kg: when several workouts fall into one bar, the best one counts. nil for
    /// bars without a workout. [trainingId] nil means all trainings.
    static func bestWorkoutVolume(_ workouts: [Workout], slots: [StatsSlot], trainingId: String?, calendar: Calendar) -> [Double?] {
        let matching = workouts.filter { trainingId == nil || $0.trainingId == trainingId }
        return slots.map { slot in
            matching.filter { slot.contains(Day($0.startedAt, calendar: calendar)) }.map(\.volumeKg).max()
        }
    }

    /// The exercise's value in each slot, or nil where it wasn't done.
    static func exerciseValues(_ workouts: [Workout], slots: [StatsSlot], exerciseId: String, metric: ExerciseMetric, calendar: Calendar) -> [Double?] {
        slots.map { slot in
            exerciseValue(workouts.filter { slot.contains(Day($0.startedAt, calendar: calendar)) }, exerciseId: exerciseId, metric: metric)
        }
    }

    /// The exercise's value on the last day it was done before [date], or nil if it never was.
    static func valueBefore(_ workouts: [Workout], date: Day, exerciseId: String, metric: ExerciseMetric, calendar: Calendar) -> Double? {
        let lastDay = workouts
            .filter { Day($0.startedAt, calendar: calendar) < date && exerciseValue([$0], exerciseId: exerciseId, metric: metric) != nil }
            .map { Day($0.startedAt, calendar: calendar) }
            .max()
        guard let lastDay else { return nil }
        return exerciseValue(workouts.filter { Day($0.startedAt, calendar: calendar) == lastDay }, exerciseId: exerciseId, metric: metric)
    }

    /// When the first slot has no value, the line starts from the last value before the range, so it begins
    /// at the left edge. Without an earlier value the series stays as it is.
    static func carryPrevious(_ values: [Double?], previous: Double?) -> [Double?] {
        guard let first = values.first, first == nil, let previous else { return values }
        return [previous] + values.dropFirst()
    }

    /// Three evenly spaced gridlines, top first, that contain every value.
    static func gridLines(_ values: [Double]) -> [Double] {
        var low = values.min() ?? 0
        var high = values.max() ?? 0
        if high - low < 1e-9 {
            // A flat line sits in the middle: 100 kg → 105 / 100 / 95.
            let spread = max(high * 0.05, 1)
            low = max(0, low - spread)
            high += spread
        }
        var magnitude = 0.1
        while true {
            for base in [1, 2, 2.5, 5] {
                let step = base * magnitude
                let bottom = (low / step).rounded(.down) * step
                let top = bottom + 2 * step
                if top >= high { return [top, bottom + step, bottom] }
            }
            magnitude *= 10
        }
    }

    /// Workouts started between [range]'s ends.
    static func within(_ workouts: [Workout], range: StatsSlot, calendar: Calendar) -> [Workout] {
        workouts.filter { range.contains(Day($0.startedAt, calendar: calendar)) }
    }

    /// Exercises whose best set weight in [range] beats every earlier workout: new personal records. The
    /// first time an exercise is done doesn't count.
    static func personalRecords(_ workouts: [Workout], range: StatsSlot, calendar: Calendar) -> Int {
        let before = workouts.filter { Day($0.startedAt, calendar: calendar) < range.start }
        let inRange = within(workouts, range: range, calendar: calendar)
        let exerciseIds = Set(inRange.flatMap { $0.exercises.map(\.exercise.id) })
        return exerciseIds.count { id in
            guard let best = exerciseValue(inRange, exerciseId: id, metric: .maximum),
                  let previousBest = exerciseValue(before, exerciseId: id, metric: .maximum) else { return false }
            return best > previousBest
        }
    }

    private static func exerciseValue(_ workouts: [Workout], exerciseId: String, metric: ExerciseMetric) -> Double? {
        let sets = workouts
            .flatMap { $0.exercises.filter { $0.exercise.id == exerciseId }.flatMap(\.sets) }
            .filter { $0.status == .done }
        switch metric {
        case .set: return sets.map(\.volumeKg).max()
        case .maximum: return sets.map { $0.weightKg ?? 0 }.max()
        }
    }

    private static func days(_ range: StatsSlot) -> [StatsSlot] {
        (range.start.epochDay...range.end.epochDay).map { StatsSlot(start: Day(epochDay: $0), end: Day(epochDay: $0)) }
    }

    /// Calendar months of [range]; the last one ends at [range]'s end.
    private static func months(_ range: StatsSlot) -> [StatsSlot] {
        var result: [StatsSlot] = []
        var month = range.start.startOfMonth
        while month <= range.end {
            result.append(StatsSlot(start: month, end: min(month.adding(days: month.lengthOfMonth - 1), range.end)))
            month = month.adding(months: 1)
        }
        return result
    }
}

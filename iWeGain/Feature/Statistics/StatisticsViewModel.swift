import Foundation

/// Statistics of the selected person for the last 7 days, month (28 to 31 days) or 12 months: KPI tiles,
/// the best workout volume per bar, and the progress of one exercise (biggest set or maximum set weight).
final class StatisticsViewModel: BaseViewModel<StatisticsState, StatisticsAction, StatisticsEvent> {
    /// What the user picked; the data is rebuilt from it whenever something changes.
    private struct Selection {
        var period: StatsPeriod = .month
        var trainingId: String?
        var exerciseId: String?
        var metric: ExerciseMetric = .maximum
        /// The tapped bar; nil selects the latest bar with a workout.
        var barIndex: Int?
    }

    private let userRepository: UserRepository
    private let syncManager: SyncManager
    private let workoutRepository: WorkoutRepository
    private let trainingRepository: TrainingRepository
    private let settingsRepository: SettingsRepository
    private let now: () -> Date
    private let calendar: Calendar
    private var isObserving = false

    private var selection = Selection()
    private var data: (workouts: [Workout], trainings: [Training])?
    private var unit: WeightUnit = .kg

    init(
        userRepository: UserRepository,
        syncManager: SyncManager,
        workoutRepository: WorkoutRepository,
        trainingRepository: TrainingRepository,
        settingsRepository: SettingsRepository,
        now: @escaping () -> Date,
        calendar: Calendar = .current
    ) {
        self.userRepository = userRepository
        self.syncManager = syncManager
        self.workoutRepository = workoutRepository
        self.trainingRepository = trainingRepository
        self.settingsRepository = settingsRepository
        self.now = now
        self.calendar = calendar
        super.init(initialState: StatisticsState())
    }

    override func onAction(_ action: StatisticsAction) {
        switch action {
        case .onAppear: observe()
        case .onUserTap(let id): userRepository.selectUser(id)
        case .onCreateProfileTap: sendEvent(.navigateToCreateProfile)
        case .onInviteTap: sendEvent(.navigateToInvite)
        case .onPeriodTap(let period):
            selection.period = period
            selection.barIndex = nil
            rebuild()
        case .onBarTap(let index):
            selection.barIndex = index
            rebuild()
        case .onTrainingChooserTap: updateState { $0.picker = .training }
        case .onExerciseChooserTap: updateState { $0.picker = .exercise }
        case .onOptionSelected(let option):
            switch state.picker {
            case .training:
                selection.trainingId = option.id
                selection.barIndex = nil
            case .exercise: selection.exerciseId = option.id
            case nil: break
            }
            updateState { $0.picker = nil }
            rebuild()
        case .onPickerDismiss: updateState { $0.picker = nil }
        case .onMetricTap(let metric):
            selection.metric = metric
            rebuild()
        case .onCreateTrainingTap: sendEvent(.navigateToNewTraining)
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            for await status in syncManager.observeStatus() { updateState { $0.isOffline = status == .offline } }
        }
        launch { [self] in
            let selected = userRepository.observeSelectedUserId()
            for await (users, selectedId) in combineLatest(userRepository.observeUsers(), selected) {
                updateState { $0.users = users.map { $0.toUserUi(isSelected: $0.id == selectedId) } }
            }
        }
        launch { [self] in
            let personData = userRepository.observeSelectedUserId().flatMapLatest { [workoutRepository, trainingRepository] userId in
                combineLatest(workoutRepository.observeFinishedWorkouts(userId: userId), trainingRepository.observeTrainings(userId: userId))
            }
            for await (workouts, trainings) in personData {
                data = (workouts, trainings)
                rebuild()
            }
        }
        launch { [self] in
            for await settings in settingsRepository.observeSettings() {
                unit = settings.weightUnit
                rebuild()
            }
        }
    }

    private func rebuild() {
        guard let data else { return }
        let (workouts, trainings) = data
        let period = selection.period
        let today = Day(now(), calendar: calendar)
        let range = StatisticsMath.range(period, today: today)
        let inRange = StatisticsMath.within(workouts, range: range, calendar: calendar)
        let inPrevious = StatisticsMath.within(workouts, range: StatisticsMath.previousPeriod(period, today: today), calendar: calendar)

        // Exercises the person has done, most recent first; the chart follows the chosen one or the latest.
        var seen = Set<String>()
        let exercises = workouts.sorted { $0.startedAt > $1.startedAt }
            .flatMap { $0.exercises.filter { $0.doneCount > 0 }.map(\.exercise) }
            .filter { seen.insert($0.id).inserted }
        let exercise = exercises.first { $0.id == selection.exerciseId } ?? exercises.first
        let training = trainings.first { $0.id == selection.trainingId }

        let volumeNow = inRange.reduce(0) { $0 + $1.volumeKg }
        let volumeBefore = inPrevious.reduce(0) { $0 + $1.volumeKg }
        let minutesNow = inRange.reduce(0) { $0 + Self.minutes($1) }
        let minutesBefore = inPrevious.reduce(0) { $0 + Self.minutes($1) }
        let records = StatisticsMath.personalRecords(workouts, range: range, calendar: calendar)
        let countChange = inRange.count - inPrevious.count

        updateState {
            $0.period = period
            $0.isLoading = false
            $0.isEmpty = workouts.isEmpty
            $0.workouts = KpiUi(value: inRange.count.formatted(), caption: comparison(Self.signed(countChange), period), trend: Self.trend(Double(countChange)))
            $0.volume = KpiUi(
                value: volumeText(volumeNow),
                // A percentage needs something to compare with; otherwise show the amount itself.
                caption: comparison(volumeBefore > 0 ? Self.percentChange(volumeNow, volumeBefore) : volumeText(volumeNow, prefix: "+"), period),
                trend: Self.trend(volumeNow - volumeBefore)
            )
            $0.timeTrained = KpiUi(
                value: Strings.format("stats_duration", minutesNow / 60, minutesNow % 60),
                caption: comparison(Self.signedDuration(minutesNow - minutesBefore), period),
                trend: Self.trend(Double(minutesNow - minutesBefore))
            )
            $0.records = KpiUi(value: records.formatted(), caption: Strings.text("stats_records_caption"), trend: records > 0 ? .up : .flat)
            $0.volumeChart = volumeChart(workouts, period: period, training: training, today: today)
            $0.exerciseChart = exercise.map { exerciseChart(workouts, period: period, today: today, exercise: $0) }
            $0.trainingOptions = [ChooserOptionUi(id: nil, name: Strings.text("stats_all_trainings"))]
                + trainings.map { ChooserOptionUi(id: $0.id, name: $0.name) }
            $0.exerciseOptions = exercises.map { ChooserOptionUi(id: $0.id, name: $0.name) }
        }
    }

    private func volumeChart(_ workouts: [Workout], period: StatsPeriod, training: Training?, today: Day) -> VolumeChartUi {
        let slots = StatisticsMath.barSlots(period, today: today)
        let volumes = StatisticsMath.bestWorkoutVolume(workouts, slots: slots, trainingId: training?.id, calendar: calendar)
        let highest = volumes.compactMap { $0 }.max() ?? 0
        // By default the latest bar with a workout, up to today.
        let selected = selection.barIndex.map { min(max($0, 0), slots.count - 1) }
            ?? volumes.indices.last { volumes[$0] != nil && slots[$0].start <= today }
            ?? slots.firstIndex { $0.contains(today) }
            ?? 0
        let bars = slots.indices.map { index in
            let volume = volumes[index] ?? 0
            return BarUi(
                label: barLabel(period, slots[index]),
                fraction: highest > 0 ? volume / highest : 0,
                isSelected: index == selected,
                description: Strings.format("stats_bar_description", slotCaption(period, slots[index]), unit.volumeText(volume))
            )
        }
        return VolumeChartUi(
            trainingId: training?.id,
            training: training?.name ?? Strings.text("stats_all_trainings"),
            bars: bars,
            value: unit.volumeText(volumes[selected] ?? 0),
            caption: slotCaption(period, slots[selected]),
            barWidth: period == .week ? 26 : period == .month ? 20 : 18
        )
    }

    private func exerciseChart(_ workouts: [Workout], period: StatsPeriod, today: Day, exercise: Exercise) -> ExerciseChartUi {
        let metric = selection.metric
        let slots = StatisticsMath.lineSlots(period, today: today)
        let values = StatisticsMath.exerciseValues(workouts, slots: slots, exerciseId: exercise.id, metric: metric, calendar: calendar)
        let before = StatisticsMath.valueBefore(workouts, date: slots[0].start, exerciseId: exercise.id, metric: metric, calendar: calendar)
        let series = StatisticsMath.carryPrevious(values, previous: before).enumerated().compactMap { index, kg in
            kg.map { LineChartPoint(slot: index, value: unit.fromKg($0)) }
        }
        guard let first = series.first?.value, let last = series.last?.value else {
            return ExerciseChartUi(exerciseId: exercise.id, exerciseName: exercise.name, metric: metric, value: nil, delta: nil, trend: .flat, chart: nil)
        }
        let grid = StatisticsMath.gridLines(series.map(\.value))
        let change = last - first
        return ExerciseChartUi(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            metric: metric,
            value: weightText(metric == .maximum ? Weights.number(last) : Int(last.rounded()).formatted()),
            delta: series.count > 1 ? signedWeight(change) : nil,
            trend: Self.trend(change),
            chart: LineChartUi(
                slotCount: slots.count,
                points: series,
                grid: grid,
                gridLabels: grid.map(Self.compactNumber),
                ticks: lineTicks(period, slots),
                description: Strings.format("stats_exercise_chart_description", exercise.name, weightText(Weights.number(first)), weightText(Weights.number(last)))
            )
        )
    }

    // MARK: Labels and formatting

    private func barLabel(_ period: StatsPeriod, _ slot: StatsSlot) -> String {
        switch period {
        case .week: slot.start.middayDate.formatted(.dateTime.weekday(.abbreviated))
        // The bars are counted back from today, so each is labelled with its last day and the last bar shows today.
        case .month: String(slot.end.day)
        case .year: slot.start.middayDate.formatted(.dateTime.month(.abbreviated))
        }
    }

    /// "Fri, Oct 2", "Sep 28 – 30" or "September 2026", in the device's language.
    private func slotCaption(_ period: StatsPeriod, _ slot: StatsSlot) -> String {
        if period == .year { return slot.start.monthTitle }
        if slot.start != slot.end {
            return (slot.start.middayDate..<slot.end.middayDate).formatted(.interval.month(.abbreviated).day())
        }
        return period == .week ? slot.start.shortTitle : slot.start.middayDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private func lineTicks(_ period: StatsPeriod, _ slots: [StatsSlot]) -> [LineChartTick] {
        switch period {
        case .week:
            slots.indices.map { LineChartTick(slot: $0, label: slots[$0].start.middayDate.formatted(.dateTime.weekday(.abbreviated))) }
        // Every 7th day counted back from today, so the last tick is today's date.
        case .month:
            slots.indices.filter { (slots.count - 1 - $0) % 7 == 0 }.map { LineChartTick(slot: $0, label: String(slots[$0].start.day)) }
        case .year:
            slots.indices.map { LineChartTick(slot: $0, label: slots[$0].start.middayDate.formatted(.dateTime.month(.abbreviated))) }
        }
    }

    /// "+3 vs previous 7 days", "vs previous month", "vs previous 12 months".
    private func comparison(_ change: String, _ period: StatsPeriod) -> String {
        switch period {
        case .week: Strings.format("stats_vs_previous_week", change)
        case .month: Strings.format("stats_vs_previous_month", change)
        case .year: Strings.format("stats_vs_previous_year", change)
        }
    }

    /// Big totals: "840 kg", then "1.2t" / "214t" from 1,000 kg ("1.2k lb" in pounds); [prefix] is a sign: "+3.2t".
    private func volumeText(_ kg: Double, prefix: String = "") -> String {
        let value = unit.fromKg(kg)
        if value < 1000 { return weightText(prefix + Int(value.rounded()).formatted()) }
        let thousands = value / 1000
        let number = thousands >= 100 ? Int(thousands.rounded()).formatted() : Weights.number((thousands * 10).rounded() / 10)
        return Strings.format(unit == .kg ? "stats_tonnes" : "stats_thousand_lb", prefix + number)
    }

    private func signedWeight(_ change: Double) -> String {
        let rounded = (change * 10).rounded() / 10
        let number = rounded > 0 ? "+\(Weights.number(rounded))" : rounded < 0 ? "−\(Weights.number(-rounded))" : "0"
        return weightText(number)
    }

    /// "57.5 kg" / "126.8 lb" from a number that is already formatted.
    private func weightText(_ number: String) -> String {
        Strings.format(unit == .kg ? "weight_kg" : "weight_lb", number)
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : value < 0 ? "−\(abs(value))" : "0"
    }

    private static func percentChange(_ now: Double, _ before: Double) -> String {
        let percent = Int(((now - before) / before * 100).rounded())
        return percent > 0 ? "+\(percent)%" : percent < 0 ? "−\(abs(percent))%" : "0%"
    }

    /// "+2:10", "−0:45".
    private static func signedDuration(_ minutes: Int) -> String {
        let sign = minutes > 0 ? "+" : minutes < 0 ? "−" : ""
        return Strings.format("stats_duration_signed", sign, abs(minutes) / 60, abs(minutes) % 60)
    }

    /// Gridline labels: "100", "97.5", "12k".
    private static func compactNumber(_ value: Double) -> String {
        value >= 10_000 ? Strings.format("stats_thousands_short", Weights.number((value / 100).rounded() / 10)) : Weights.number(value)
    }

    private static func trend(_ change: Double) -> Trend {
        change > 0 ? .up : change < 0 ? .down : .flat
    }

    private static func minutes(_ workout: Workout) -> Int {
        Int((workout.finishedAt ?? workout.startedAt).timeIntervalSince(workout.startedAt) / 60)
    }
}

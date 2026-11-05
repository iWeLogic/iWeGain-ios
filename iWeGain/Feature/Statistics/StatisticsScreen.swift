import SwiftUI

struct StatisticsRoot: View {
    @State private var viewModel: StatisticsViewModel
    private let onNavigateToCreateProfile: () -> Void
    private let onNavigateToInvite: () -> Void
    private let onNavigateToNewTraining: () -> Void

    init(
        viewModel: @autoclosure () -> StatisticsViewModel,
        onNavigateToCreateProfile: @escaping () -> Void,
        onNavigateToInvite: @escaping () -> Void,
        onNavigateToNewTraining: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToCreateProfile = onNavigateToCreateProfile
        self.onNavigateToInvite = onNavigateToInvite
        self.onNavigateToNewTraining = onNavigateToNewTraining
    }

    var body: some View {
        StatisticsScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToCreateProfile: onNavigateToCreateProfile()
                case .navigateToInvite: onNavigateToInvite()
                case .navigateToNewTraining: onNavigateToNewTraining()
                }
            }
            .task { viewModel.onAction(.onAppear) }
    }
}

struct StatisticsScreen: View {
    let state: StatisticsState
    let onAction: (StatisticsAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x16) {
                UserSwitcher(
                    users: state.users,
                    isOffline: state.isOffline,
                    onUserTap: { onAction(.onUserTap(id: $0)) },
                    onCreateProfileTap: { onAction(.onCreateProfileTap) },
                    onInviteTap: { onAction(.onInviteTap) }
                )
                if !state.isLoading {
                    if state.isEmpty {
                        emptyContent
                    } else {
                        statistics
                    }
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
        }
        .background(Color.bgBase)
        .hidesNavigationBar()
        .sheet(item: Binding(get: { state.picker }, set: { if $0 == nil { onAction(.onPickerDismiss) } })) { picker in
            switch picker {
            case .training:
                OptionPickerSheet(
                    title: "stats_choose_training",
                    options: state.trainingOptions,
                    selected: state.trainingOptions.first { $0.id == state.volumeChart?.trainingId },
                    label: \.name,
                    onSelect: { onAction(.onOptionSelected($0)) }
                )
            case .exercise:
                OptionPickerSheet(
                    title: "stats_choose_exercise",
                    options: state.exerciseOptions,
                    selected: state.exerciseOptions.first { $0.id == state.exerciseChart?.exerciseId },
                    label: \.name,
                    onSelect: { onAction(.onOptionSelected($0)) }
                )
            }
        }
    }

    @ViewBuilder
    private var statistics: some View {
        AppSegmentedControl(
            options: StatsPeriod.allCases.map(\.label),
            selectedIndex: StatsPeriod.allCases.firstIndex(of: state.period) ?? 0,
            onSelect: { onAction(.onPeriodTap(StatsPeriod.allCases[$0])) }
        )
        VStack(spacing: Spacing.x12) {
            HStack(spacing: Spacing.x12) {
                KpiTile(label: "stats_workouts", kpi: state.workouts)
                KpiTile(label: "stats_total_volume", kpi: state.volume)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.x12) {
                KpiTile(label: "stats_time_trained", kpi: state.timeTrained)
                KpiTile(label: "stats_personal_records", kpi: state.records)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        if let chart = state.volumeChart {
            VolumeCard(chart: chart, onAction: onAction)
        }
        if let chart = state.exerciseChart {
            ExerciseCard(chart: chart, onAction: onAction)
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        // Placeholder bars hinting at what the screen will show.
        BarChart(
            bars: ([0.35, 0.55, 0.45, 0.75, 0.62, 0.9, 0.7, 1] as [Double]).map { BarUi(label: "", fraction: $0, isSelected: false, description: "") },
            onBarTap: { _ in },
            barWidth: 26,
            maxBarHeight: 110
        )
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .opacity(0.5)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        EmptyStateView(title: "stats_empty_title", message: "stats_empty_message", icon: "ic_chart")
        Button { onAction(.onCreateTrainingTap) } label: {
            Label { Text("stats_create_first_training") } icon: { Image("ic_plus") }
        }
        .buttonStyle(.appPrimary)
    }
}

private struct KpiTile: View {
    let label: LocalizedStringKey
    let kpi: KpiUi?

    var body: some View {
        StatTile(label: label, value: kpi?.value ?? "", caption: kpi?.caption ?? "", captionColor: kpi?.trend.color ?? .textSecondary, valueStyle: .numericMedium)
    }
}

private struct ChartHeader: View {
    let title: LocalizedStringKey
    let choice: String
    let onChooserTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            Text(title)
                .textStyle(.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            ChooserPill(text: choice, action: onChooserTap)
        }
    }
}

private struct VolumeCard: View {
    let chart: VolumeChartUi
    let onAction: (StatisticsAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.x8) {
            ChartHeader(title: "stats_volume_per_training", choice: chart.training, onChooserTap: { onAction(.onTrainingChooserTap) })
            VStack(spacing: Spacing.x2) {
                Text(chart.value).textStyle(.numericLarge).foregroundStyle(Color.textPrimary)
                Text(chart.caption).textStyle(.footnote).foregroundStyle(Color.textSecondary)
            }
            .padding(.top, Spacing.x4)
            BarChart(bars: chart.bars, onBarTap: { onAction(.onBarTap($0)) }, barWidth: chart.barWidth)
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct ExerciseCard: View {
    let chart: ExerciseChartUi
    let onAction: (StatisticsAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            ChartHeader(title: "stats_exercise_progress", choice: chart.exerciseName, onChooserTap: { onAction(.onExerciseChooserTap) })
            AppSegmentedControl(
                options: ExerciseMetric.allCases.map(\.label),
                selectedIndex: ExerciseMetric.allCases.firstIndex(of: chart.metric) ?? 0,
                onSelect: { onAction(.onMetricTap(ExerciseMetric.allCases[$0])) },
                height: 50,
                trackColor: .bgBase,
                selectedColor: .fillSelected
            )
            if let value = chart.value, let line = chart.chart {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.x8) {
                    Text(value).textStyle(.numericLarge).foregroundStyle(Color.textPrimary)
                    if let delta = chart.delta {
                        Text(delta).textStyle(.subhead).foregroundStyle(chart.trend.color)
                    }
                }
                LineChart(chart: line)
            } else {
                Text(Strings.format("stats_no_exercise_data", chart.exerciseName))
                    .textStyle(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.x24)
            }
        }
        .padding(Spacing.x16)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

private extension Trend {
    var color: Color {
        switch self {
        case .up: .statusSuccess
        case .down: .statusDanger
        case .flat: .textSecondary
        }
    }
}

private extension StatsPeriod {
    var label: LocalizedStringResource {
        switch self {
        case .week: "stats_week"
        case .month: "stats_month"
        case .year: "stats_year"
        }
    }
}

private extension ExerciseMetric {
    var label: LocalizedStringResource {
        switch self {
        case .set: "stats_set"
        case .maximum: "stats_maximum"
        }
    }
}

#Preview("Statistics") {
    NavigationStack {
        StatisticsScreen(
            state: StatisticsState(
                users: [UserUi(id: "1", name: "Alex Kim", initials: "AK", avatarColor: .blue, isSelected: true)],
                isLoading: false,
                workouts: KpiUi(value: "18", caption: "+3 vs previous month", trend: .up),
                volume: KpiUi(value: "214t", caption: "+12% vs previous month", trend: .up),
                timeTrained: KpiUi(value: "21h 40m", caption: "+2:10 vs previous month", trend: .up),
                records: KpiUi(value: "7", caption: "New records", trend: .up),
                volumeChart: VolumeChartUi(
                    trainingId: nil,
                    training: "All trainings",
                    bars: ([0.78, 0.83, 0, 0.86, 0.85, 0.92, 0.89, 0, 0.95, 1] as [Double]).enumerated().map { (index: Int, fraction: Double) -> BarUi in
                        BarUi(label: String(index * 3 + 1), fraction: fraction, isSelected: index == 9, description: "")
                    },
                    value: "15,200 kg",
                    caption: "Sep 28 – 30",
                    barWidth: 20
                ),
                exerciseChart: ExerciseChartUi(
                    exerciseId: "bench_press", exerciseName: "Bench Press", metric: .maximum, value: "100 kg", delta: "+7.5 kg", trend: .up,
                    chart: LineChartUi(
                        slotCount: 30,
                        points: [LineChartPoint(slot: 0, value: 92.5), LineChartPoint(slot: 14, value: 97.5), LineChartPoint(slot: 28, value: 100)],
                        grid: [100, 95, 90],
                        gridLabels: ["100", "95", "90"],
                        ticks: [LineChartTick(slot: 0, label: "1"), LineChartTick(slot: 14, label: "15"), LineChartTick(slot: 28, label: "29")],
                        description: ""
                    )
                )
            ),
            onAction: { _ in }
        )
    }
}

#Preview("Empty") {
    NavigationStack { StatisticsScreen(state: StatisticsState(isLoading: false, isEmpty: true), onAction: { _ in }) }
}

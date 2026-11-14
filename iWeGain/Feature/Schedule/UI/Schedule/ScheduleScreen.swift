import SwiftUI

struct ScheduleRoot: View {
    @State private var viewModel: ScheduleViewModel
    @State private var errorMessage: LocalizedStringResource?
    /// A training picked in Select training, handed over by the navigation; [takePickedTraining] takes it, once.
    private let pickedTrainingId: String?
    private let takePickedTraining: () -> String?
    private let onNavigateToSelectTraining: (String?) -> Void
    private let onClose: () -> Void

    init(
        viewModel: @autoclosure () -> ScheduleViewModel,
        pickedTrainingId: String?,
        takePickedTraining: @escaping () -> String?,
        onNavigateToSelectTraining: @escaping (String?) -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.pickedTrainingId = pickedTrainingId
        self.takePickedTraining = takePickedTraining
        self.onNavigateToSelectTraining = onNavigateToSelectTraining
        self.onClose = onClose
    }

    var body: some View {
        ScheduleScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToSelectTraining(let selectedId): onNavigateToSelectTraining(selectedId)
                case .close: onClose()
                case .showError(let message): errorMessage = message
                }
            }
            .errorAlert($errorMessage)
            .task { viewModel.onAction(.onAppear) }
            .onChange(of: pickedTrainingId, initial: true) { _, id in
                // Taking the pick clears it: this can run twice for one pick (the change, then "initial" as the
                // view reappears, both with the old value), and only the first run may use it.
                guard id != nil, let id = takePickedTraining() else { return }
                viewModel.onAction(.onTrainingPicked(id: id))
            }
    }
}

/// "Schedule training" (Figma 30 / 32): pick a training and a time for a day, and whether it repeats
/// every week. Opened on a planned training, it edits or removes it; for a weekly series
/// "Apply to all repeats" decides whether that changes only this day or every week.
struct ScheduleScreen: View {
    let state: ScheduleState
    let onAction: (ScheduleAction) -> Void

    var body: some View {
        ScrollView {
            if !state.isLoading {
                VStack(alignment: .leading, spacing: Spacing.x12) {
                    Text(state.dateTitle)
                        .textStyle(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)

                    SectionLabel(text: Strings.text("schedule_training")).padding(.top, Spacing.x8)
                    if let training = state.training {
                        TrainingSelectField(title: training.name, subtitle: training.exercises, icon: training.icon) {
                            onAction(.onSelectTrainingTap)
                        }
                    } else {
                        TrainingSelectField(
                            title: Strings.text("schedule_select_training"),
                            subtitle: Strings.text("schedule_select_training_hint")
                        ) { onAction(.onSelectTrainingTap) }
                    }

                    SectionLabel(text: Strings.text("schedule_time")).padding(.top, Spacing.x8)
                    GroupCard {
                        TimeRow(label: "schedule_starts", time: state.startTime) { onAction(.onStartTimeChange($0)) }
                        Rectangle().fill(Color.borderDefault).frame(height: 1)
                        TimeRow(label: "schedule_ends", time: state.endTime) { onAction(.onEndTimeChange($0)) }
                    }
                    if !state.isTimeValid {
                        Text("schedule_end_before_start").textStyle(.footnote).foregroundStyle(Color.statusDanger)
                    }

                    GroupCard {
                        if state.isPartOfSeries {
                            Text(Strings.format("schedule_repeats", state.weekdayName))
                                .textStyle(.body)
                                .foregroundStyle(Color.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            Rectangle().fill(Color.borderDefault).frame(height: 1)
                            Toggle(isOn: Binding(get: { state.applyToAll }, set: { onAction(.onApplyToAllChange($0)) })) {
                                Text("schedule_apply_to_all").textStyle(.body).foregroundStyle(Color.textPrimary)
                            }
                            .tint(Color.switchOn)
                            .frame(minHeight: 48)
                        } else {
                            Toggle(isOn: Binding(get: { state.repeatsWeekly }, set: { onAction(.onRepeatChange($0)) })) {
                                VStack(alignment: .leading, spacing: Spacing.x2) {
                                    Text("schedule_repeat").textStyle(.body).foregroundStyle(Color.textPrimary)
                                    Text(Strings.format("schedule_repeat_hint", state.weekdayName))
                                        .textStyle(.footnote)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .tint(Color.switchOn)
                            .padding(.vertical, Spacing.x8)
                        }
                    }

                    Button { onAction(.onSaveTap) } label: {
                        Label {
                            Text(state.isNew ? "schedule_confirm" : "schedule_save")
                        } icon: {
                            Image(state.isNew ? "ic_calendar" : "ic_check")
                        }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(!state.canSave)
                    .padding(.top, Spacing.x8)
                    if !state.isNew {
                        Button { onAction(.onRemoveTap) } label: {
                            Label { Text("schedule_remove") } icon: { Image("ic_trash") }
                        }
                        .buttonStyle(.appDanger)
                    }
                }
                .padding(.horizontal, Spacing.x16)
                .padding(.bottom, Spacing.x16)
            }
        }
        .background(Color.bgBase)
        .navigationTitle(Text(state.isNew ? "schedule_title" : "schedule_edit_title"))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action_cancel") { onAction(.onCancelTap) }
            }
        }
    }
}

/// Rows on a grey rounded card (the time and repeat groups).
private struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x8)
            .background(Color.bgSurface2, in: .rect(cornerRadius: Radius.lg))
    }
}

/// "Starts 18:00": the system's compact time picker; 12/24-hour follows the device setting.
private struct TimeRow: View {
    let label: LocalizedStringKey
    let time: TimeOfDay
    let onChange: (TimeOfDay) -> Void

    var body: some View {
        DatePicker(
            selection: Binding(get: { time.pickerDate() }, set: { onChange(TimeOfDay($0)) }),
            displayedComponents: .hourAndMinute
        ) {
            Text(label).textStyle(.body).foregroundStyle(Color.textPrimary)
        }
        .tint(Color.accentPrimary)
        .padding(.vertical, Spacing.x8)
    }
}

#Preview("Edit a repeat") {
    NavigationStack {
        ScheduleScreen(
            state: ScheduleState(
                entryId: "s1",
                dateTitle: "Thu, Oct 8",
                training: TrainingChoiceUi(id: "t1", name: "Pull Day", icon: "ic_zap", exercises: "5 exercises"),
                isPartOfSeries: true,
                weekdayName: "Thursday"
            ),
            onAction: { _ in }
        )
    }
}

#Preview("New") {
    NavigationStack {
        ScheduleScreen(state: ScheduleState(dateTitle: "Thu, Oct 8", weekdayName: "Thursday"), onAction: { _ in })
    }
}

import SwiftUI

struct ExerciseLibraryRoot: View {
    @State private var viewModel: ExerciseLibraryViewModel
    @State private var errorMessage: LocalizedStringResource?
    private let onExercisePicked: (String) -> Void

    init(viewModel: @autoclosure () -> ExerciseLibraryViewModel, onExercisePicked: @escaping (String) -> Void) {
        _viewModel = State(initialValue: viewModel())
        self.onExercisePicked = onExercisePicked
    }

    var body: some View {
        ExerciseLibraryScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .exercisePicked(let id): onExercisePicked(id)
                case .showError(let message): errorMessage = message
                }
            }
            .errorAlert($errorMessage)
            .task { viewModel.onAction(.onAppear) }
    }
}

struct ExerciseLibraryScreen: View {
    let state: ExerciseLibraryState
    let onAction: (ExerciseLibraryAction) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.x16) {
                AddActionCard(
                    title: "exercise_library_create_custom",
                    subtitle: "exercise_library_create_custom_hint",
                    action: { onAction(.onCreateCustomTap) }
                )
                .padding(.horizontal, Spacing.x16)
                .padding(.top, Spacing.x8)
                SearchField(placeholder: "exercise_library_search", text: state.query, onTextChange: { onAction(.onQueryChange($0)) })
                    .padding(.horizontal, Spacing.x16)
                MuscleGroupFilter(selected: state.selectedMuscleGroup, onSelect: { onAction(.onMuscleGroupTap($0)) })
                ForEach(state.sections) { section in
                    SectionCard(section: section, onAction: onAction)
                        .padding(.horizontal, Spacing.x16)
                }
                if state.isEmpty {
                    Text("exercise_library_no_results")
                        .textStyle(.callout)
                        .foregroundStyle(Color.textSecondary)
                        .padding(Spacing.x24)
                }
            }
            .padding(.bottom, Spacing.x16)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.bgBase)
        .navigationTitle(Text("exercise_library_title"))
        .inlineNavigationTitle()
        .sheet(isPresented: Binding(get: { state.form != nil }, set: { if !$0 { onAction(.onFormDismiss) } })) {
            if let form = state.form {
                ExerciseFormSheet(form: form, onAction: onAction)
            }
        }
    }
}

private struct MuscleGroupFilter: View {
    let selected: MuscleGroup?
    let onSelect: (MuscleGroup?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.x8) {
                Chip(label: "exercise_library_all", isSelected: selected == nil, action: { onSelect(nil) })
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Chip(label: group.label, isSelected: group == selected, action: { onSelect(group) })
                }
            }
            .padding(.horizontal, Spacing.x16)
        }
    }
}

private struct SectionCard: View {
    let section: ExerciseSectionUi
    let onAction: (ExerciseLibraryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            SectionLabel(text: String(localized: section.muscleGroup.label))
            VStack(spacing: 0) {
                ForEach(Array(section.exercises.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 { ExerciseRowDivider() }
                    ExerciseRow(
                        icon: exercise.icon,
                        title: exercise.name,
                        subtitle: exercise.subtitle,
                        action: { onAction(.onExerciseTap(id: exercise.id)) },
                        onEdit: exercise.isCustom ? { onAction(.onEditCustomTap(id: exercise.id)) } : nil
                    )
                }
            }
            .clipShape(.rect(cornerRadius: Radius.lg))
        }
    }
}

/// The exercise sheet. New: "Create and add" adds it to the training. Edit (custom exercise): "Save" updates it.
private struct ExerciseFormSheet: View {
    let form: ExerciseFormState
    let onAction: (ExerciseLibraryAction) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x20) {
                    FormSection(label: "new_exercise_name") {
                        HStack(spacing: Spacing.x12) {
                            if let icon = form.icon {
                                IconOption(icon: icon.imageName, isSelected: true, action: { onAction(.onFormIconTap) }, size: 46)
                                    .accessibilityLabel(Text("new_exercise_change_icon"))
                            } else {
                                EmptyIconOption(action: { onAction(.onFormIconTap) }, size: 46, isError: form.isIconMissing)
                                    .accessibilityLabel(Text("new_exercise_choose_icon"))
                            }
                            AppTextField(
                                placeholder: "new_exercise_name_placeholder",
                                text: form.name,
                                onTextChange: { onAction(.onFormNameChange($0)) },
                                dashedWhenEmpty: true,
                                isError: form.isNameMissing,
                                background: .bgSurface2
                            )
                        }
                    }
                    FormSection(label: "new_exercise_muscle_group") {
                        FlowLayout {
                            ForEach(MuscleGroup.allCases, id: \.self) { group in
                                Chip(label: group.label, isSelected: form.muscleGroup == group, action: { onAction(.onFormMuscleGroupTap(group)) },
                                     background: .bgSurface2, isError: form.isMuscleGroupMissing)
                            }
                        }
                    }
                    FormSection(label: "new_exercise_equipment") {
                        FlowLayout {
                            ForEach(Equipment.allCases, id: \.self) { equipment in
                                Chip(label: equipment.label, isSelected: form.equipment == equipment, action: { onAction(.onFormEquipmentTap(equipment)) },
                                     background: .bgSurface2, isError: form.isEquipmentMissing)
                            }
                        }
                    }
                    Button { onAction(.onFormSubmit) } label: {
                        Label {
                            Text(form.isEditing ? "edit_exercise_save" : "new_exercise_create")
                        } icon: {
                            Image(form.isEditing ? "ic_check" : "ic_plus").resizable().frame(width: 20, height: 20)
                        }
                    }
                    .buttonStyle(.appPrimary)
                }
                .padding(Spacing.x16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bgSurface)
            .navigationTitle(Text(form.isEditing ? "edit_exercise_title" : "new_exercise_title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCloseButton() }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bgSurface)
        .sheet(isPresented: Binding(get: { form.isIconPickerOpen }, set: { if !$0 { onAction(.onFormIconDismiss) } })) {
            IconPickerSheet(selection: form.icon, onSelect: { onAction(.onFormIconSelect($0)) })
        }
    }
}

private struct FormSection<Content: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            Text(label).textStyle(.caption).foregroundStyle(Color.textSecondary)
            content()
        }
    }
}

#Preview("Library") {
    NavigationStack {
        ExerciseLibraryScreen(
            state: ExerciseLibraryState(
                sections: [
                    ExerciseSectionUi(muscleGroup: .chest, exercises: [
                        ExerciseRowUi(id: "1", icon: "ic_ex_barbell_bench_press", name: "Bench Press", subtitle: "Chest · Barbell", isCustom: false),
                        ExerciseRowUi(id: "2", icon: "ic_flame", name: "Landmine Press", subtitle: "Chest · Barbell", isCustom: true),
                    ]),
                ],
                isLoading: false
            ),
            onAction: { _ in }
        )
    }
}

#Preview("New exercise") {
    ExerciseFormSheet(form: ExerciseFormState(showMissing: true), onAction: { _ in })
}

import SwiftUI

/// Sheet with a single-choice list. Tapping an option applies it; the caller closes the sheet.
struct OptionPickerSheet<Option: Hashable>: View {
    let title: LocalizedStringKey
    let options: [Option]
    let selected: Option?
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { index in
                        if index > 0 { Divider().overlay(Color.borderDefault).padding(.leading, Spacing.x16) }
                        row(options[index])
                    }
                }
                .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                .padding(.horizontal, Spacing.x16)
                .padding(.bottom, Spacing.x24)
            }
            .background(Color.bgBase)
            .navigationTitle(Text(title))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.bgBase)
    }

    private func row(_ option: Option) -> some View {
        Button { onSelect(option) } label: {
            HStack {
                Text(label(option))
                    .textStyle(.body)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if option == selected {
                    Image("ic_check")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option == selected ? .isSelected : [])
    }
}

#Preview {
    Color.bgBase.sheet(isPresented: .constant(true)) {
        OptionPickerSheet(title: "settings_units", options: ["Kilograms (kg)", "Pounds (lb)"], selected: "Kilograms (kg)", label: { $0 }, onSelect: { _ in })
    }
}

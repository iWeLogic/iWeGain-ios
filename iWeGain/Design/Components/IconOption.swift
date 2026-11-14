import SwiftUI

/// Square icon tile. Selected tiles get the accent fill and border (training icon picker).
struct IconOption: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    var size: CGFloat = 56
    var isEnabled = true

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.accentPrimary : Color.textSecondary)
                .frame(width: size, height: size)
                .background(isSelected ? Color.accentSoft : Color.bgSurface, in: .rect(cornerRadius: Radius.md))
                .insideBorder(isSelected ? .accentPrimary : .clear, cornerRadius: Radius.md)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Tile shown before any icon is chosen: dashed border and a pencil.
struct EmptyIconOption: View {
    let action: () -> Void
    var size: CGFloat = 56
    /// Picking an icon is required and none was picked: red border.
    var isError = false

    var body: some View {
        Button(action: action) {
            Image("ic_pencil")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.textSecondary)
                .frame(width: size, height: size)
                .background(Color.bgSurface, in: .rect(cornerRadius: Radius.md))
                .modifier(EmptyTileBorder(isError: isError))
        }
        .buttonStyle(.pressable)
    }
}

private struct EmptyTileBorder: ViewModifier {
    let isError: Bool

    func body(content: Content) -> some View {
        if isError {
            content.insideBorder(.statusDanger, cornerRadius: Radius.md)
        } else {
            content.dashedBorder(.borderDefault, cornerRadius: Radius.md, dash: 4, gap: 3)
        }
    }
}

/// "Choose icon" sheet: a 5-column grid of every [ItemIcon]. Tapping one applies it and closes the sheet.
struct IconPickerSheet: View {
    let selection: ItemIcon?
    let onSelect: (ItemIcon) -> Void

    var body: some View {
        NavigationStack {
            FittedSheetScroll {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.x12), count: 5), spacing: Spacing.x12) {
                    ForEach(ItemIcon.allCases, id: \.self) { icon in
                        IconOption(icon: icon.imageName, isSelected: icon == selection, action: { onSelect(icon) })
                            .accessibilityLabel(icon.rawValue)
                    }
                }
                .padding(Spacing.x16)
            }
            .navigationTitle(Text("choose_icon_title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCloseButton() }
            }
            .background(Color.bgBase)
        }
        .presentationBackground(Color.bgBase)
    }
}

/// The ✕ that closes a sheet.
struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(role: .close) { dismiss() }
    }
}

#Preview {
    HStack {
        IconOption(icon: "ic_dumbbell", isSelected: true, action: {}, size: 46)
        EmptyIconOption(action: {}, size: 46)
        EmptyIconOption(action: {}, size: 46, isError: true)
    }
    .padding()
    .background(Color.bgBase)
}

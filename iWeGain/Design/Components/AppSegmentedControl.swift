import SwiftUI

/// Equal-width single choice (Figma "Segment"): the Week / Month / Year tabs, or Set / Maximum inside a
/// chart card, where it uses a darker track and a 50 pt height.
struct AppSegmentedControl: View {
    let options: [LocalizedStringResource]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    var height: CGFloat = 40
    var trackColor: Color = .bgSurface
    var selectedColor: Color = .bgSurface2

    var body: some View {
        HStack(spacing: Spacing.x4) {
            ForEach(options.indices, id: \.self) { index in
                let isSelected = index == selectedIndex
                Button {
                    onSelect(index)
                } label: {
                    Text(options[index])
                        .textStyle(.subhead)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isSelected ? selectedColor : .clear, in: .rect(cornerRadius: 8))
                        .contentShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Spacing.x4)
        .frame(height: height)
        .background(trackColor, in: .rect(cornerRadius: 12))
        .animation(.snappy(duration: 0.2), value: selectedIndex)
    }
}

#Preview {
    @Previewable @State var selected = 1
    AppSegmentedControl(options: ["Week", "Month", "Year"], selectedIndex: selected, onSelect: { selected = $0 })
        .padding()
        .background(Color.bgBase)
}

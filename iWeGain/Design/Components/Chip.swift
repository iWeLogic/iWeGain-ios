import SwiftUI

/// Pill-shaped filter/choice chip.
struct Chip: View {
    let label: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void
    var background: Color = .bgSurface
    /// One of these chips has to be picked and none is: red border.
    var isError = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .textStyle(.subhead)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.accentOn : Color.textPrimary)
                .padding(.horizontal, Spacing.x12)
                .padding(.vertical, Spacing.x8)
                .background(isSelected ? Color.accentPrimary : background, in: .capsule)
                .overlay(
                    Capsule().inset(by: isError ? 0.75 : 0.5)
                        .stroke(isSelected ? .clear : (isError ? Color.statusDanger : Color.borderDefault), lineWidth: isError ? 1.5 : 1)
                )
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Lays its children out in rows, wrapping to the next row when one is full (chip groups).
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.x8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

#Preview {
    FlowLayout {
        Chip(label: "All", isSelected: true, action: {})
        Chip(label: "Chest", isSelected: false, action: {})
        Chip(label: "Shoulders", isSelected: false, action: {})
        Chip(label: "Full body", isSelected: false, action: {}, isError: true)
    }
    .padding()
    .background(Color.bgBase)
}

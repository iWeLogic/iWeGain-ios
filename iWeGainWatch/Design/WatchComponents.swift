import SwiftUI

enum WatchButtonKind {
    case primary, secondary, disabled
}

/// Figma "Watch Button": a pill. Longer labels (Ukrainian, Russian and Spanish ones) shrink to fit.
struct WatchPillButton: View {
    @Environment(\.watchScale) private var scale
    let title: LocalizedStringKey
    var kind = WatchButtonKind.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .watchText(16, .semiBold, color: foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12 * scale)
                .frame(maxWidth: .infinity, minHeight: 40 * scale)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(kind == .disabled)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .watchBgBase
        case .secondary: .watchTextPrimary
        case .disabled: .watchTextTertiary
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .watchAccent
        case .secondary: .watchBgSurface2
        case .disabled: .watchBgSurface
        }
    }
}

/// A round button: − / + in Log Set, −15 / +15 next to the rest timer.
struct WatchRoundButton<Label: View>: View {
    @Environment(\.watchScale) private var scale
    let accessibilityText: Text
    var isEnabled = true
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(isEnabled ? Color.watchTextPrimary : Color.watchTextTertiary)
                .frame(width: 36 * scale, height: 36 * scale)
                .background(Color.watchBgSurface2, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityText)
    }
}

struct WatchIcon: View {
    @Environment(\.watchScale) private var scale
    let name: String
    let size: CGFloat
    var color = Color.watchTextPrimary

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size * scale, height: size * scale)
            .accessibilityHidden(true)
    }
}

/// The rest ring along the edge of the screen, starting at the top and draining with the countdown.
nonisolated struct RestEdgeShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

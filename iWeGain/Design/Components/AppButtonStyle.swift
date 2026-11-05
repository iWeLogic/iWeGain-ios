import SwiftUI

/// Full-width 52 pt buttons: [primary] is the screen's main call to action, [secondary] a neutral
/// action, [danger] a destructive one. Disabled buttons turn grey.
struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.headline)
            .lineLimit(1)
            // Long translations shrink instead of breaking a word across lines.
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Spacing.x16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? foreground : Color.textTertiary)
            .background(isEnabled ? background : Color.bgSurface2, in: .rect(cornerRadius: Radius.md))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect(cornerRadius: Radius.md))
    }

    private var foreground: Color {
        switch kind {
        case .primary: .accentOn
        case .secondary: .textPrimary
        case .danger: .statusDanger
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .accentPrimary
        case .secondary: .bgSurface2
        case .danger: .statusDangerSoft
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var appPrimary: AppButtonStyle { AppButtonStyle(kind: .primary) }
    static var appSecondary: AppButtonStyle { AppButtonStyle(kind: .secondary) }
    static var appDanger: AppButtonStyle { AppButtonStyle(kind: .danger) }
}

#Preview {
    VStack(spacing: Spacing.x16) {
        Button("Start training", systemImage: "plus") {}.buttonStyle(.appPrimary)
        Button("Start training", systemImage: "plus") {}.buttonStyle(.appSecondary)
        Button("Delete") {}.buttonStyle(.appDanger)
        Button("Start training") {}.buttonStyle(.appPrimary).disabled(true)
    }
    .padding(Spacing.x16)
    .background(Color.bgBase)
}

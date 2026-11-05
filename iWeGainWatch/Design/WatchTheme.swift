import SwiftUI

/// The phone app's dark palette; the watch is always dark.
extension Color {
    static let watchBgBase = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0F / 255)
    static let watchBgSurface = Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x1D / 255)
    static let watchBgSurface2 = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x2B / 255)
    static let watchBorder = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x36 / 255)
    static let watchTextPrimary = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let watchTextSecondary = Color(red: 0x9C / 255, green: 0x9C / 255, blue: 0xA8 / 255)
    static let watchTextTertiary = Color(red: 0x5F / 255, green: 0x5F / 255, blue: 0x6B / 255)
    static let watchAccent = Color(red: 0xC6 / 255, green: 0xFF / 255, blue: 0x3D / 255)
}

enum WatchFontWeight: String {
    case regular = "Inter-Regular", medium = "Inter-Medium", semiBold = "Inter-SemiBold", bold = "Inter-Bold"
}

/// Sizes are for the 45 mm watch (198 points wide) and follow the screen, like the Figma frames on Wear OS.
struct WatchScale: EnvironmentKey {
    static let designWidth: CGFloat = 198
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var watchScale: CGFloat {
        get { self[WatchScale.self] }
        set { self[WatchScale.self] = newValue }
    }
}

private struct WatchText: ViewModifier {
    @Environment(\.watchScale) private var scale
    let size: CGFloat
    let weight: WatchFontWeight
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.custom(weight.rawValue, fixedSize: size * scale))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}

extension View {
    func watchText(_ size: CGFloat, _ weight: WatchFontWeight = .regular, color: Color = .watchTextPrimary) -> some View {
        modifier(WatchText(size: size, weight: weight, color: color))
    }
}

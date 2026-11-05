import SwiftUI

extension View {
    /// Dashed stroke drawn inside the bounds, like a Figma "inside" dashed border.
    func dashedBorder(_ color: Color, cornerRadius: CGFloat, lineWidth: CGFloat = 1.5, dash: CGFloat = 6, gap: CGFloat = 4) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: lineWidth / 2)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: [dash, gap]))
        )
    }

    /// Solid stroke drawn inside the bounds.
    func insideBorder(_ color: Color, cornerRadius: CGFloat, lineWidth: CGFloat = 1.5) -> some View {
        overlay(RoundedRectangle(cornerRadius: cornerRadius).inset(by: lineWidth / 2).stroke(color, lineWidth: lineWidth))
    }
}

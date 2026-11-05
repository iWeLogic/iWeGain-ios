import SwiftUI

/// Small confirmation pill, e.g. "⏭ Set 2 skipped  Undo".
struct StatusPill: View {
    let text: String
    let icon: String
    var background: Color = .accentSoft
    var iconColor: Color = .accentPrimary
    var actionTitle: LocalizedStringKey?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.x8) {
            Image(icon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(iconColor)
            Text(text)
                .textStyle(.subhead)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .padding(.vertical, Spacing.x8)
            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .textStyle(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, actionTitle == nil ? 14 : Spacing.x4)
        .background(background, in: .capsule)
    }
}

#Preview {
    StatusPill(text: "Set 2 skipped", icon: "ic_skip_forward", background: .bgSurface2, iconColor: .textPrimary, actionTitle: "action_undo")
        .padding()
        .background(Color.bgBase)
}

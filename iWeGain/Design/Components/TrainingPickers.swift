import SwiftUI

/// Field that opens the training picker (Figma "Training Select Field"). [icon] nil shows the empty
/// state: dashed border and a "+" badge.
struct TrainingSelectField: View {
    let title: String
    let subtitle: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x12) {
                if let icon {
                    IconBadge(asset: icon, size: 40, cornerRadius: Radius.sm)
                } else {
                    IconBadge(asset: "ic_plus", size: 40, cornerRadius: Radius.sm, foreground: .textPrimary, background: .bgSurface)
                }
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title)
                        .textStyle(icon == nil ? .body : .headline)
                        .foregroundStyle(icon == nil ? Color.textSecondary : Color.textPrimary)
                        .lineLimit(1)
                    Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("ic_chevron_right")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(Spacing.x12)
            .background(Color.bgSurface2, in: .rect(cornerRadius: Radius.lg))
            .dashedBorder(icon == nil ? Color.borderDefault : .clear, cornerRadius: Radius.lg)
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
    }
}

/// Selectable training in a list (Figma "Training Option"): badge, name, count and a radio check.
struct TrainingOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x12) {
                IconBadge(asset: icon, size: 40, cornerRadius: Radius.sm)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary).lineLimit(1)
                    Text(subtitle).textStyle(.footnote).foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPrimary : .clear)
                        .overlay(Circle().inset(by: 0.75).stroke(isSelected ? .clear : Color.textTertiary, lineWidth: 1.5))
                    if isSelected {
                        Image("ic_check").resizable().frame(width: 16, height: 16).foregroundStyle(Color.accentOn)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(Spacing.x12)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .insideBorder(isSelected ? Color.accentPrimary : Color.borderDefault, cornerRadius: Radius.lg)
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: Spacing.x12) {
        TrainingSelectField(title: "Select training", subtitle: "Choose from your trainings", action: {})
        TrainingSelectField(title: "Pull Day", subtitle: "5 exercises", icon: "ic_zap", action: {})
        TrainingOption(icon: "ic_zap", title: "Pull Day", subtitle: "5 exercises", isSelected: true, action: {})
        TrainingOption(icon: "ic_mountain", title: "Leg Day", subtitle: "5 exercises", isSelected: false, action: {})
    }
    .padding()
    .background(Color.bgBase)
}

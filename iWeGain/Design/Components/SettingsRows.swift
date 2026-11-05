import SwiftUI

/// Labeled group of settings rows in a rounded container, e.g. "PREFERENCES". Separate rows with [SettingsDivider].
struct SettingsGroup<Content: View>: View {
    /// String Catalog key.
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x8) {
            SectionLabel(text: Strings.text(label))
            VStack(spacing: 0) { content }
                .frame(maxWidth: .infinity)
                .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
                .clipShape(.rect(cornerRadius: Radius.lg))
        }
    }
}

/// Settings row with a value and a chevron, e.g. "Units · kg ›".
struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    var value: String?
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLayout(icon: icon, title: title, isDestructive: isDestructive) {
                if let value {
                    Text(value).textStyle(.callout).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
                Image("ic_chevron_right")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Settings row with a toggle.
struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        SettingsRowLayout(icon: icon, title: title, isDestructive: false) {
            Toggle(isOn: Binding(get: { isOn }, set: onChange)) { Text(title) }
                .labelsHidden()
                .tint(Color.switchOn)
        }
    }
}

/// Divider between settings rows, inset to start after the icon.
struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Color.borderDefault).frame(height: 1).padding(.leading, 60)
    }
}

private struct SettingsRowLayout<Trailing: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let isDestructive: Bool
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let color: Color = isDestructive ? .statusDanger : .textPrimary
        HStack(spacing: Spacing.x12) {
            IconBadge(asset: icon, size: 32, iconSize: 18, cornerRadius: Radius.xs, foreground: color, background: .bgSurface2)
            Text(title)
                .textStyle(.body)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, Spacing.x16)
        .padding(.vertical, Spacing.x12)
        .contentShape(.rect)
    }
}

#Preview {
    SettingsGroup(label: "settings_preferences") {
        SettingsRow(icon: "ic_dumbbell", title: "settings_units", value: "kg", action: {})
        SettingsDivider()
        SettingsToggleRow(icon: "ic_bell", title: "settings_workout_reminders", isOn: true, onChange: { _ in })
        SettingsDivider()
        SettingsRow(icon: "ic_trash", title: "settings_delete_account", isDestructive: true, action: {})
    }
    .padding()
    .background(Color.bgBase)
}

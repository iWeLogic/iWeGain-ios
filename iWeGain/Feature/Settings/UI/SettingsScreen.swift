import SwiftUI
import UserNotifications

struct SettingsRoot: View {
    @State private var viewModel: SettingsViewModel
    @State private var message: String?
    @Environment(\.openURL) private var openURL
    private let onNavigateToSignIn: () -> Void
    private let onNavigateToMyTeam: () -> Void
    private let onNavigateToMyProfile: () -> Void
    private let onNavigateToTeamsImIn: () -> Void

    init(
        viewModel: @autoclosure () -> SettingsViewModel,
        onNavigateToSignIn: @escaping () -> Void,
        onNavigateToMyTeam: @escaping () -> Void,
        onNavigateToMyProfile: @escaping () -> Void,
        onNavigateToTeamsImIn: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel())
        self.onNavigateToSignIn = onNavigateToSignIn
        self.onNavigateToMyTeam = onNavigateToMyTeam
        self.onNavigateToMyProfile = onNavigateToMyProfile
        self.onNavigateToTeamsImIn = onNavigateToTeamsImIn
    }

    var body: some View {
        SettingsScreen(state: viewModel.state, onAction: viewModel.onAction)
            .onEvents(of: viewModel) { event in
                switch event {
                case .navigateToSignIn: onNavigateToSignIn()
                case .navigateToMyTeam: onNavigateToMyTeam()
                case .navigateToMyProfile: onNavigateToMyProfile()
                case .navigateToTeamsImIn: onNavigateToTeamsImIn()
                case .openURL(let url): openURL(url)
                case .showMessage(let text): message = text
                case .requestNotificationPermission:
                    Task {
                        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                        if !granted { viewModel.onAction(.onNotificationsDenied) }
                    }
                }
            }
            .alert(
                Text(message ?? ""),
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
                actions: { Button("action_ok") {} }
            )
            .task { viewModel.onAction(.onAppear) }
    }
}

struct SettingsScreen: View {
    let state: SettingsState
    let onAction: (SettingsAction) -> Void

    var body: some View {
        let settings = state.settings
        ScrollView {
            VStack(spacing: Spacing.x20) {
                if let account = state.account {
                    AccountCard(account: account, action: { onAction(.onAccountTap) })
                    VStack(alignment: .leading, spacing: Spacing.x8) {
                        SettingsGroup(label: "settings_teams") {
                            SettingsRow(icon: "ic_user", title: "my_team_title", value: Strings.plural("settings_team_people", state.teamSize), action: { onAction(.onMyTeamTap) })
                            SettingsDivider()
                            SettingsRow(icon: "ic_shield", title: "teams_im_in_title", value: String(state.teamsImIn), action: { onAction(.onTeamsImInTap) })
                        }
                        Text("settings_teams_hint")
                            .textStyle(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Spacing.x4)
                    }
                } else {
                    SignInCard(action: { onAction(.onSignInTap) })
                }
                SettingsGroup(label: "settings_preferences") {
                    SettingsRow(icon: "ic_dumbbell", title: "settings_units", value: Strings.text(settings.weightUnit.shortKey), action: { onAction(.onUnitsTap) })
                    SettingsDivider()
                    SettingsRow(icon: "ic_clock", title: "settings_default_rest", value: state.defaultRest, action: { onAction(.onRestTimerTap) })
                    SettingsDivider()
                    SettingsToggleRow(icon: "ic_bell", title: "settings_workout_reminders", isOn: settings.workoutReminders, onChange: { onAction(.onRemindersChange($0)) })
                    if settings.workoutReminders {
                        SettingsDivider()
                        SettingsRow(icon: "ic_timer", title: "settings_remind_me", value: state.reminderTime, action: { onAction(.onReminderTimeTap) })
                    }
                    SettingsDivider()
                    SettingsRow(icon: "ic_moon", title: "settings_theme", value: Strings.text(settings.themeMode.labelKey), action: { onAction(.onThemeTap) })
                }
                SettingsGroup(label: "settings_about") {
                    SettingsRow(icon: "ic_flag", title: "legal_terms", action: { onAction(.onTermsTap) })
                    SettingsDivider()
                    SettingsRow(icon: "ic_shield", title: "legal_privacy", action: { onAction(.onPrivacyTap) })
                }
                if state.account != nil {
                    SettingsGroup(label: "settings_data") {
                        SettingsRow(icon: "ic_logout", title: "settings_log_out", isDestructive: true, action: { onAction(.onLogOutTap) })
                        SettingsDivider()
                        SettingsRow(icon: "ic_trash", title: "settings_delete_account", isDestructive: true, action: { onAction(.onDeleteAccountTap) })
                    }
                }
            }
            .padding(.horizontal, Spacing.x16)
            .padding(.vertical, Spacing.x12)
        }
        .background(Color.bgBase)
        .hidesNavigationBar()
        .sheet(item: Binding(get: { state.openPicker }, set: { if $0 == nil { onAction(.onPickerDismiss) } })) { picker in
            switch picker {
            case .units:
                OptionPickerSheet(title: "settings_units", options: WeightUnit.allCases, selected: settings.weightUnit,
                                  label: { Strings.text($0.longKey) }, onSelect: { onAction(.onUnitSelect($0)) })
            case .restTimer:
                OptionPickerSheet(title: "settings_default_rest", options: SettingsViewModel.restOptionsSeconds, selected: settings.defaultRestSeconds,
                                  label: Durations.rest, onSelect: { onAction(.onRestSelect($0)) })
            case .reminderTime:
                OptionPickerSheet(title: "settings_remind_me", options: SettingsViewModel.reminderOptionsMinutes, selected: settings.reminderMinutesBefore,
                                  label: SettingsViewModel.reminderTimeText, onSelect: { onAction(.onReminderTimeSelect($0)) })
            case .theme:
                OptionPickerSheet(title: "settings_theme", options: ThemeMode.allCases, selected: settings.themeMode,
                                  label: { Strings.text($0.labelKey) }, onSelect: { onAction(.onThemeSelect($0)) })
            }
        }
        .centeredDialog(isPresented: state.isLogOutDialogVisible, onDismiss: { onAction(.onLogOutDismiss) }) {
            ConfirmDialog(
                title: Strings.text("settings_log_out_title"),
                message: Strings.text("settings_log_out_message"),
                confirmText: Strings.text("settings_log_out"),
                dismissText: Strings.text("action_cancel"),
                isDestructive: true,
                onConfirm: { onAction(.onLogOutConfirm) },
                onDismiss: { onAction(.onLogOutDismiss) }
            ) {
                IconBadge(asset: "ic_logout", size: 64, iconSize: 28, cornerRadius: 32, foreground: .statusDanger, background: .statusDangerSoft)
            }
        }
        .centeredDialog(isPresented: state.deleteCountdown != nil, onDismiss: { onAction(.onDeleteAccountDismiss) }) {
            let secondsLeft = state.deleteCountdown ?? 0
            ConfirmDialog(
                title: Strings.text("settings_delete_account_title"),
                message: Strings.text(state.account?.confirmsWithApple == true ? "settings_delete_account_message_apple" : "settings_delete_account_message"),
                confirmText: secondsLeft > 0 ? Strings.format("settings_delete_account_countdown", secondsLeft) : Strings.text("settings_delete_account"),
                dismissText: Strings.text("action_cancel"),
                isDestructive: true,
                isWorking: state.isDeletingAccount,
                isConfirmEnabled: secondsLeft == 0,
                onConfirm: { onAction(.onDeleteAccountConfirm) },
                onDismiss: { onAction(.onDeleteAccountDismiss) }
            )
        }
    }
}

/// "Sign in to save your progress" card shown while nobody is signed in.
private struct SignInCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.x12) {
            IconBadge(asset: "ic_user", size: 64, iconSize: 30, cornerRadius: 32)
            Text("settings_sign_in_title").textStyle(.title2).foregroundStyle(Color.textPrimary).multilineTextAlignment(.center)
            Text("settings_sign_in_message").textStyle(.callout).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
            Button("settings_sign_in", action: action).buttonStyle(.appPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.x20)
        .padding(.vertical, Spacing.x24)
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
    }
}

/// Signed-in account header: avatar, name, contact and "Member since"; tapping it opens My profile.
private struct AccountCard: View {
    let account: AccountUi
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x16) {
                Avatar(initials: account.initials, color: .blue, photo: account.photo, isSelected: true, size: 56)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(account.name).textStyle(.title2).foregroundStyle(Color.textPrimary).lineLimit(1)
                    if let detail = account.detail {
                        Text(detail).textStyle(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                    }
                    if let memberSince = account.memberSince {
                        Text(memberSince).textStyle(.footnote).foregroundStyle(Color.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("ic_chevron_right").resizable().frame(width: 18, height: 18).foregroundStyle(Color.textTertiary)
            }
            .padding(Spacing.x16)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.pressable)
        .accessibilityHint(Text("profile_me_title"))
    }
}

private extension ThemeMode {
    var labelKey: String {
        switch self {
        case .system: "settings_theme_system"
        case .light: "settings_theme_light"
        case .dark: "settings_theme_dark"
        }
    }
}

private extension WeightUnit {
    /// Short unit shown as the row value ("kg").
    var shortKey: String { self == .kg ? "unit_kg" : "unit_lb" }
    /// Full unit name for the picker ("Kilograms (kg)").
    var longKey: String { self == .kg ? "unit_kg_long" : "unit_lb_long" }
}

#Preview("Guest") {
    NavigationStack { SettingsScreen(state: SettingsState(defaultRest: "3 min", reminderTime: "30 min before"), onAction: { _ in }) }
}

#Preview("Signed in") {
    NavigationStack {
        SettingsScreen(
            state: SettingsState(
                account: AccountUi(initials: "AK", name: "Alex Kim", detail: "alex.kim@mail.com", memberSince: "Member since March 2026"),
                defaultRest: "3 min",
                reminderTime: "30 min before"
            ),
            onAction: { _ in }
        )
    }
}

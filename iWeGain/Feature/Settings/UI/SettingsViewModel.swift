import Foundation

final class SettingsViewModel: BaseViewModel<SettingsState, SettingsAction, SettingsEvent> {
    static let restOptionsSeconds = [30, 45, 60, 90, 120, 150, 180, 240, 300]
    static let reminderOptionsMinutes = [0, 15, 30, 60]
    static let deleteCountdownSeconds = 10

    private let settingsRepository: SettingsRepository
    private let authRepository: AuthRepository
    private let accountRepository: AccountRepository
    private let teamRepository: TeamRepository
    private let profileRepository: ProfileRepository
    private var isObserving = false
    private var deleteCountdownTask: Task<Void, Never>?

    init(
        settingsRepository: SettingsRepository,
        authRepository: AuthRepository,
        accountRepository: AccountRepository,
        teamRepository: TeamRepository,
        profileRepository: ProfileRepository
    ) {
        self.settingsRepository = settingsRepository
        self.authRepository = authRepository
        self.accountRepository = accountRepository
        self.teamRepository = teamRepository
        self.profileRepository = profileRepository
        super.init(initialState: SettingsState())
    }

    static func reminderTimeText(_ minutes: Int) -> String {
        minutes == 0 ? Strings.text("settings_remind_at_start") : Strings.format("settings_remind_before", minutes)
    }

    override func onAction(_ action: SettingsAction) {
        switch action {
        case .onAppear: observe()
        case .onSignInTap: sendEvent(.navigateToSignIn)
        case .onAccountTap: sendEvent(.navigateToMyProfile)
        case .onMyTeamTap: sendEvent(.navigateToMyTeam)
        case .onTeamsImInTap: sendEvent(.navigateToTeamsImIn)
        case .onTermsTap: sendEvent(.openURL(LegalLinks.terms))
        case .onPrivacyTap: sendEvent(.openURL(LegalLinks.privacy))
        case .onUnitsTap: updateState { $0.openPicker = .units }
        case .onRestTimerTap: updateState { $0.openPicker = .restTimer }
        case .onReminderTimeTap: updateState { $0.openPicker = .reminderTime }
        case .onThemeTap: updateState { $0.openPicker = .theme }
        case .onPickerDismiss: updateState { $0.openPicker = nil }
        case .onUnitSelect(let unit):
            updateState { $0.openPicker = nil }
            settingsRepository.setWeightUnit(unit)
        case .onRestSelect(let seconds):
            updateState { $0.openPicker = nil }
            settingsRepository.setDefaultRestSeconds(seconds)
        case .onReminderTimeSelect(let minutes):
            updateState { $0.openPicker = nil }
            settingsRepository.setReminderMinutesBefore(minutes)
        case .onThemeSelect(let mode):
            updateState { $0.openPicker = nil }
            settingsRepository.setThemeMode(mode)
        case .onRemindersChange(let enabled):
            settingsRepository.setWorkoutReminders(enabled)
            if enabled { sendEvent(.requestNotificationPermission) }
        case .onNotificationsDenied:
            // This device's answer doesn't change the account's other devices.
            settingsRepository.setWorkoutReminders(false, syncToAccount: false)
            sendEvent(.showMessage(Strings.text("settings_notifications_blocked")))
        case .onLogOutTap: updateState { $0.isLogOutDialogVisible = true }
        case .onLogOutDismiss: updateState { $0.isLogOutDialogVisible = false }
        case .onLogOutConfirm:
            updateState { $0.isLogOutDialogVisible = false }
            launch { [accountRepository] in await accountRepository.logOut() }
        case .onDeleteAccountTap: startDeleteCountdown()
        case .onDeleteAccountConfirm: deleteAccount()
        case .onDeleteAccountDismiss:
            guard !state.isDeletingAccount else { return }
            deleteCountdownTask?.cancel()
            updateState { $0.deleteCountdown = nil }
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        launch { [self] in
            for await settings in settingsRepository.observeSettings() {
                updateState {
                    $0.settings = settings
                    $0.defaultRest = Durations.rest(settings.defaultRestSeconds)
                    $0.reminderTime = Self.reminderTimeText(settings.reminderMinutesBefore)
                }
            }
        }
        launch { [self] in
            // The name and photo I set in My profile win over the account's own.
            for await (user, profile) in combineLatest(authRepository.observeUser(), profileRepository.observeMyProfile()) {
                updateState { $0.account = user.map { Self.accountUi($0, profile: profile) } }
            }
        }
        launch { [self] in
            for await members in teamRepository.observeMyTeam() { updateState { $0.teamSize = members.count } }
        }
        launch { [self] in
            for await teams in teamRepository.observeMemberships() { updateState { $0.teamsImIn = teams.count } }
        }
    }

    /// The dialog's button stays off for a while, so the account isn't deleted by a quick tap.
    private func startDeleteCountdown() {
        deleteCountdownTask?.cancel()
        updateState { $0.deleteCountdown = Self.deleteCountdownSeconds }
        deleteCountdownTask = Task { [weak self] in
            for _ in 0..<Self.deleteCountdownSeconds {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.updateState { $0.deleteCountdown = $0.deleteCountdown.map { max(0, $0 - 1) } }
            }
        }
    }

    private func deleteAccount() {
        guard state.deleteCountdown == 0, !state.isDeletingAccount else { return }
        launch { [self] in
            updateState { $0.isDeletingAccount = true }
            do throws(AuthError) {
                try await accountRepository.deleteAccount()
                updateState { $0.deleteCountdown = nil }
                sendEvent(.showMessage(Strings.text("settings_delete_account_done")))
            } catch {
                if let message = Self.deleteErrorText(error) { sendEvent(.showMessage(message)) }
            }
            updateState { $0.isDeletingAccount = false }
        }
    }

    /// nil when the user closed the account picker: the dialog stays open to try again.
    private static func deleteErrorText(_ error: AuthError) -> String? {
        switch error {
        case .cancelled: nil
        case .noInternet: Strings.text("auth_error_no_internet")
        case .wrongAccount: Strings.text("auth_error_wrong_account")
        case .noGoogleAccount, .tooManyRequests, .notConfigured, .methodDisabled, .accountExists, .unknown: Strings.text("settings_delete_account_failed")
        }
    }

    private static func accountUi(_ user: AuthUser, profile: AccountProfile?) -> AccountUi {
        // Google accounts have a name and email; phone accounts often only a number.
        let ownName = profile?.name.nonBlank ?? user.name
        let title = ownName ?? user.phoneNumber ?? user.email
        return AccountUi(
            initials: ownName.map(User.initials(of:)) ?? "#",
            name: title ?? Strings.text("settings_account_fallback_name"),
            detail: [user.email, user.phoneNumber].compactMap { $0 }.first { $0 != title },
            memberSince: user.createdAt.map { Strings.format("settings_member_since", $0.formatted(.dateTime.month(.wide).year())) },
            photo: profile?.photo,
            confirmsWithApple: user.provider == .apple
        )
    }
}

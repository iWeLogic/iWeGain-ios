import Foundation

struct SettingsState: Equatable {
    /// The signed-in account; nil shows the sign-in card.
    var account: AccountUi?
    var settings = AppSettings()
    var defaultRest = ""
    /// "30 min before" / "At start"; shown while reminders are on.
    var reminderTime = ""
    var openPicker: SettingsPicker?
    /// People in my team and teams I'm in; shown while signed in.
    var teamSize = 0
    var teamsImIn = 0
    /// The "Log out?" confirmation is open.
    var isLogOutDialogVisible = false
    /// Seconds until "Delete account" can be pressed; nil hides the dialog, 0 enables the button.
    var deleteCountdown: Int?
    var isDeletingAccount = false
}

enum SettingsPicker: Hashable, Identifiable {
    case units, restTimer, reminderTime, theme
    var id: Self { self }
}

struct AccountUi: Equatable {
    let initials: String
    let name: String
    /// Email or phone number shown under the name.
    let detail: String?
    let memberSince: String?
    var photo: Data?
    /// Deleting the account is confirmed with the Apple ID instead of the Google account.
    var confirmsWithApple = false
}

enum SettingsAction {
    case onAppear
    /// The account card: edit my name and photo.
    case onAccountTap
    case onSignInTap
    case onUnitsTap
    case onRestTimerTap
    case onUnitSelect(WeightUnit)
    case onRestSelect(Int)
    case onPickerDismiss
    case onRemindersChange(Bool)
    case onReminderTimeTap
    case onReminderTimeSelect(Int)
    /// The user didn't allow notifications after turning reminders on.
    case onNotificationsDenied
    case onThemeTap
    case onThemeSelect(ThemeMode)
    case onLogOutTap
    case onLogOutConfirm
    case onLogOutDismiss
    case onDeleteAccountTap
    case onDeleteAccountConfirm
    case onDeleteAccountDismiss
    case onMyTeamTap
    case onTeamsImInTap
    case onTermsTap
    case onPrivacyTap
}

enum SettingsEvent: UiEvent {
    case navigateToSignIn
    case requestNotificationPermission
    case navigateToMyTeam
    case navigateToMyProfile
    case navigateToTeamsImIn
    case openURL(URL)
    case showMessage(String)
}

enum LegalLinks {
    static let terms = URL(string: "https://iwegain.com/terms.html")!
    static let privacy = URL(string: "https://iwegain.com/privacy.html")!
}

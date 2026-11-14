struct JoinTeamState: Equatable {
    var isLoading = true
    /// Who invited me: "Alex Kim".
    var ownerName = ""
    var ownerInitials = ""
    var isSignedIn = false
    var signingInWith: SignInProvider?
    var isSigningIn: Bool { signingInWith != nil }
    var isJoining = false
    /// The invite can't be used (expired, used, my own, not found) or something failed.
    var error: String?
}

enum JoinTeamAction {
    case onAppear
    case onJoinTap
    case onNotNowTap
    case onGoogleTap
    case onAppleTap
}

enum JoinTeamEvent: UiEvent, Equatable {
    case close
    case showMessage(String)
}

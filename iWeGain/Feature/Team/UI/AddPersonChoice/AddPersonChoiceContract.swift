struct AddPersonChoiceState: Equatable {
    /// My avatar next to the "+" at the top.
    var me: UserUi?
    /// Both ways need an account: signed out the options are dimmed and the screen asks to sign in.
    var isSignedIn = true
}

enum AddPersonChoiceAction {
    case onAppear
    case onCloseTap
    case onCreateProfileTap
    case onInviteTap
    case onSignInTap
}

enum AddPersonChoiceEvent: UiEvent, Equatable {
    case close
    case navigateToCreateProfile
    case navigateToInvite
    case navigateToSignIn
}

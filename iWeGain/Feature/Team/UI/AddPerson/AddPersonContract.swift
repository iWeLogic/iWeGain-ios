import Foundation

struct AddPersonState: Equatable {
    /// My avatar next to the "+" at the top.
    var me: UserUi?
    /// Inviting needs an account; signed out the screen asks to sign in first.
    var isSignedIn = true
    var isCreating = false
    /// "https://iwegain.com/i/AK7-29QX" once the invite is created.
    var link: URL?
    var error: String?
}

enum AddPersonAction {
    case onAppear
    case onCloseTap
    case onCopyTap
    case onRetryTap
    case onSignInTap
}

enum AddPersonEvent: UiEvent, Equatable {
    case close
    case navigateToSignIn
    case copyLink(URL)
}

import Foundation

struct MyTeamState: Equatable {
    var isLoading = true
    var members: [MemberUi] = []
    /// The member being removed: shows the confirmation dialog.
    var removing: MemberUi?
    var isRemoving = false
}

struct MemberUi: Identifiable, Equatable {
    let uid: String
    let name: String
    let initials: String
    let color: AvatarColor
    /// "Joined Sep 12", plus "· Hasn't allowed access" when they keep their data to themselves; "Profile in your account" for a profile.
    let caption: String
    /// A profile I created inside my account: tapping it edits it, and removing it deletes it with its data.
    var isProfile = false
    var photo: Data?

    var id: String { uid }

    /// The part of the name the dialogs use.
    var firstName: String { String(name.prefix { $0 != " " }) }
}

enum MyTeamAction {
    case onAppear
    case onInviteTap
    case onCreateProfileTap
    case onMemberTap(MemberUi)
    case onRemoveTap(MemberUi)
    case onRemoveConfirm
    case onRemoveDismiss
}

enum MyTeamEvent: UiEvent, Equatable {
    case navigateToInvite
    case navigateToCreateProfile
    case navigateToEditProfile(profileId: String)
    case showMessage(String)
}

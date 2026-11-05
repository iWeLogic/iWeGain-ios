struct TeamsImInState: Equatable {
    var isLoading = true
    var teams: [MembershipUi] = []
    /// The team being left: shows the confirmation dialog.
    var leaving: MembershipUi?
    var isLeaving = false
}

struct MembershipUi: Identifiable, Equatable {
    let ownerUid: String
    let ownerName: String
    let initials: String
    let color: AvatarColor
    /// "Team leader · joined Sep 29".
    let caption: String
    /// The team leader can see and change my trainings, exercises, workouts and schedule.
    var hasAccess: Bool

    var id: String { ownerUid }
}

enum TeamsImInAction {
    case onAppear
    case onAccessChange(ownerUid: String, access: Bool)
    case onLeaveTap(MembershipUi)
    case onLeaveConfirm
    case onLeaveDismiss
}

enum TeamsImInEvent: UiEvent, Equatable {
    case showMessage(String)
}

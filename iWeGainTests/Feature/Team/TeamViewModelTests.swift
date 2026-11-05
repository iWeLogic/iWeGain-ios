import Foundation
import Testing
@testable import iWeGain

/// Tests run signed out and without Firebase: the lists are empty, and anything that needs an account fails.
@MainActor
struct TeamViewModelTests {
    private let container = AppContainer.inMemory()

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { await Task.yield() }
    }

    // MARK: Invite links

    @Test(arguments: [
        ("https://iwegain.com/i/AK7-29QX", "AK7-29QX"),
        ("https://iwegain.com/i/AK7-29QX?source=share", "AK7-29QX"),
        ("https://iwegain.com/i/AK7-29QX/", "AK7-29QX"),
        ("https://iwegain.com/i/", nil),
        ("https://iwegain.com/terms.html", nil),
        ("iwegain://workout/overview", nil),
    ] as [(String, String?)])
    func inviteLinksGiveTheirCode(link: String, code: String?) {
        #expect(TeamInvite.code(fromLink: URL(string: link)!) == code)
    }

    // MARK: Errors

    @Test(arguments: [
        (TeamError.notSignedIn, "team_error_not_signed_in"),
        (.inviteNotFound, "team_error_invite_not_found"),
        (.inviteExpired, "team_error_invite_expired"),
        (.inviteUsed, "team_error_invite_used"),
        (.ownInvite, "team_error_own_invite"),
        (.noInternet, "auth_error_no_internet"),
        (.unknown, "team_error_unknown"),
    ])
    func teamErrorsHaveAMessage(error: TeamError, key: String) {
        #expect(error.messageKey == key)
        #expect(error.message != key)
    }

    @Test(arguments: [
        (ProfileError.notSignedIn, "team_error_not_signed_in"),
        (.photo, "profile_error_photo"),
        (.noInternet, "auth_error_no_internet"),
        (.unknown, "team_error_unknown"),
    ])
    func profileErrorsHaveAMessage(error: ProfileError, key: String) {
        #expect(error.messageKey == key)
        #expect(error.message != key)
    }

    // MARK: My team

    @Test func membersComeBeforeProfilesOldestFirstWithTheNamesAndColorsOfThePeopleList() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let members = MyTeamViewModel.members(
            team: [
                TeamMember(uid: "pending", name: "Pending Person", hasAccess: true, joinedAt: nil),
                TeamMember(uid: "late", name: "Old Name", hasAccess: true, joinedAt: late),
                TeamMember(uid: "early", name: "Dan Petrov", hasAccess: false, joinedAt: early),
            ],
            profiles: [
                Profile(id: "p2", firstName: "Newer", lastName: "", avatarColor: .blue, photo: nil, createdAt: nil),
                Profile(id: "p1", firstName: "Leo", lastName: "Novak", avatarColor: .purple, photo: Data([1]), createdAt: early),
            ],
            users: [User(id: "late", name: "Maria Sokol", avatarColor: .orange, photo: Data([2]))]
        )

        #expect(members.map(\.uid) == ["early", "late", "pending", "p1", "p2"])
        let late0 = members[1]
        #expect(late0.name == "Maria Sokol")
        #expect(late0.initials == "MS")
        #expect(late0.color == .orange)
        #expect(late0.photo == Data([2]))
        #expect(!late0.isProfile)
        // Someone who isn't in the people list yet.
        #expect(members[0].name == "Dan Petrov")
        #expect(members[0].color == .pink)
        #expect(members[3].isProfile)
        #expect(members[3].initials == "LN")
        #expect(members[3].color == .purple)
    }

    @Test func captionsSayWhenSomeoneJoinedAndWhetherTheyAllowAccess() {
        let joinedAt = Date(timeIntervalSince1970: 1_000_000)
        let date = joinedAt.formatted(.dateTime.month(.abbreviated).day())
        let members = MyTeamViewModel.members(
            team: [
                TeamMember(uid: "a", name: "A", hasAccess: true, joinedAt: joinedAt),
                TeamMember(uid: "b", name: "B", hasAccess: false, joinedAt: joinedAt.addingTimeInterval(1)),
                TeamMember(uid: "c", name: "C", hasAccess: true, joinedAt: nil),
            ],
            profiles: [Profile(id: "p", firstName: "P", lastName: "", avatarColor: .blue, photo: nil, createdAt: nil)],
            users: []
        )

        let joined = Strings.format("my_team_joined", date)
        #expect(members[0].caption == joined)
        #expect(members[1].caption == Strings.format("my_team_no_access", Strings.format("my_team_joined", joinedAt.addingTimeInterval(1).formatted(.dateTime.month(.abbreviated).day()))))
        #expect(members[2].caption == Strings.text("my_team_just_joined"))
        #expect(members[3].caption == Strings.text("my_team_profile_caption"))
    }

    @Test func myTeamStopsLoadingWithNobodyInIt() async {
        let viewModel = container.makeMyTeamViewModel()
        #expect(viewModel.state.isLoading)
        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }
        #expect(!viewModel.state.isLoading)
        #expect(viewModel.state.members.isEmpty)
    }

    @Test func onlyProfilesOpenWhenTapped() {
        let viewModel = container.makeMyTeamViewModel()
        var events: [MyTeamEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onMemberTap(member(isProfile: false)))
        viewModel.onAction(.onMemberTap(member(isProfile: true)))
        viewModel.onAction(.onInviteTap)
        viewModel.onAction(.onCreateProfileTap)

        #expect(events == [.navigateToEditProfile(profileId: "id"), .navigateToInvite, .navigateToCreateProfile])
    }

    @Test(arguments: [false, true])
    func aFailedRemovalClosesTheDialogAndSaysWhy(isProfile: Bool) async {
        let viewModel = container.makeMyTeamViewModel()
        var events: [MyTeamEvent] = []
        viewModel.subscribe { events.append($0) }
        let member = member(isProfile: isProfile)

        viewModel.onAction(.onRemoveTap(member))
        #expect(viewModel.state.removing == member)
        viewModel.onAction(.onRemoveConfirm)
        await viewModel.waitForTasks()

        #expect(viewModel.state.removing == nil)
        #expect(!viewModel.state.isRemoving)
        #expect(events == [.showMessage(Strings.text("team_error_not_signed_in"))])
    }

    @Test func dismissingTheRemovalKeepsTheMember() {
        let viewModel = container.makeMyTeamViewModel()
        viewModel.onAction(.onRemoveTap(member(isProfile: false)))
        viewModel.onAction(.onRemoveDismiss)
        #expect(viewModel.state.removing == nil)
    }

    @Test func dialogsUseTheFirstName() {
        #expect(member(isProfile: false, name: "Maria Sokol").firstName == "Maria")
        #expect(member(isProfile: false, name: "Maria").firstName == "Maria")
    }

    private func member(isProfile: Bool, name: String = "Leo Novak") -> MemberUi {
        MemberUi(uid: "id", name: name, initials: "LN", color: .blue, caption: "", isProfile: isProfile)
    }

    // MARK: Teams I'm in

    @Test func teamsAreOldestFirstWithLeaderColorsInOrder() {
        let joinedAt = Date(timeIntervalSince1970: 1_000_000)
        let teams = TeamsImInViewModel.teams([
            TeamMembership(ownerUid: "new", ownerName: "New Leader", hasAccess: true, joinedAt: nil),
            TeamMembership(ownerUid: "old", ownerName: "Alex Kim", hasAccess: false, joinedAt: joinedAt),
        ])

        #expect(teams.map(\.ownerUid) == ["old", "new"])
        #expect(teams.map(\.color) == [.blue, .orange])
        #expect(teams[0].initials == "AK")
        #expect(!teams[0].hasAccess)
        #expect(teams[0].caption == Strings.format("teams_im_in_leader_joined", joinedAt.formatted(.dateTime.month(.abbreviated).day())))
        #expect(teams[1].caption == Strings.text("teams_im_in_leader"))
    }

    @Test func teamsImInStopsLoadingWithoutTeams() async {
        let viewModel = container.makeTeamsImInViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }
        #expect(!viewModel.state.isLoading)
        #expect(viewModel.state.teams.isEmpty)
    }

    @Test func aFailedAccessChangeSaysWhy() async {
        let viewModel = container.makeTeamsImInViewModel()
        var events: [TeamsImInEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onAccessChange(ownerUid: "owner", access: false))
        await viewModel.waitForTasks()

        #expect(events == [.showMessage(Strings.text("team_error_not_signed_in"))])
    }

    @Test func aFailedLeaveClosesTheDialogAndSaysWhy() async {
        let viewModel = container.makeTeamsImInViewModel()
        var events: [TeamsImInEvent] = []
        viewModel.subscribe { events.append($0) }
        let team = MembershipUi(ownerUid: "owner", ownerName: "Alex", initials: "A", color: .blue, caption: "", hasAccess: true)

        viewModel.onAction(.onLeaveTap(team))
        #expect(viewModel.state.leaving == team)
        viewModel.onAction(.onLeaveConfirm)
        await viewModel.waitForTasks()

        #expect(viewModel.state.leaving == nil)
        #expect(!viewModel.state.isLeaving)
        #expect(events == [.showMessage(Strings.text("team_error_not_signed_in"))])
    }

    // MARK: Join

    @Test func anInviteThatCantBeLoadedShowsTheError() async {
        let viewModel = container.makeJoinTeamViewModel(code: "ABC-12345")
        #expect(viewModel.state.isLoading)

        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isLoading }

        #expect(!viewModel.state.isSignedIn)
        #expect(viewModel.state.error == Strings.text("team_error_unknown"))
    }

    @Test func notNowCloses() {
        let viewModel = container.makeJoinTeamViewModel(code: "ABC-12345")
        var events: [JoinTeamEvent] = []
        viewModel.subscribe { events.append($0) }
        viewModel.onAction(.onNotNowTap)
        #expect(events == [.close])
    }

    @Test func joiningWithoutAnInviteDoesNothing() async {
        let viewModel = container.makeJoinTeamViewModel(code: "ABC-12345")
        var events: [JoinTeamEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onJoinTap)
        await viewModel.waitForTasks()

        #expect(events.isEmpty)
        #expect(!viewModel.state.isJoining)
    }

    @Test func aFailedSignInSaysWhy() async {
        let viewModel = container.makeJoinTeamViewModel(code: "ABC-12345")
        var events: [JoinTeamEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onGoogleTap)
        await viewModel.waitForTasks()

        #expect(events == [.showMessage(Strings.text("auth_error_not_configured"))])
        #expect(!viewModel.state.isSigningIn)
    }

    // MARK: Add a person

    @Test func signedOutTheOptionsAskToSignIn() async {
        let viewModel = container.makeAddPersonChoiceViewModel()
        var events: [AddPersonChoiceEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isSignedIn }
        #expect(!viewModel.state.isSignedIn)
        #expect(viewModel.state.me?.isGuest == true)

        viewModel.onAction(.onCreateProfileTap)
        viewModel.onAction(.onInviteTap)
        #expect(events.isEmpty)

        viewModel.onAction(.onSignInTap)
        viewModel.onAction(.onCloseTap)
        #expect(events == [.navigateToSignIn, .close])
    }

    @Test func signedInTheOptionsNavigate() {
        let viewModel = container.makeAddPersonChoiceViewModel()
        var events: [AddPersonChoiceEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onCreateProfileTap)
        viewModel.onAction(.onInviteTap)

        #expect(events == [.navigateToCreateProfile, .navigateToInvite])
    }

    // MARK: Invite link

    @Test func signedOutNoInviteIsCreated() async {
        let viewModel = container.makeAddPersonViewModel()
        viewModel.onAction(.onAppear)
        await waitUntil { !viewModel.state.isSignedIn }

        #expect(!viewModel.state.isSignedIn)
        #expect(!viewModel.state.isCreating)
        #expect(viewModel.state.link == nil)
        #expect(viewModel.state.error == nil)
    }

    @Test func aFailedInviteShowsTheErrorAndCanBeRetried() async {
        let viewModel = container.makeAddPersonViewModel()

        viewModel.onAction(.onRetryTap)
        #expect(viewModel.state.isCreating)
        await viewModel.waitForTasks()

        #expect(!viewModel.state.isCreating)
        #expect(viewModel.state.error == Strings.text("team_error_not_signed_in"))
    }

    @Test func copyingWithoutALinkDoesNothing() {
        let viewModel = container.makeAddPersonViewModel()
        var events: [AddPersonEvent] = []
        viewModel.subscribe { events.append($0) }

        viewModel.onAction(.onCopyTap)
        viewModel.onAction(.onSignInTap)
        viewModel.onAction(.onCloseTap)

        #expect(events == [.navigateToSignIn, .close])
    }
}

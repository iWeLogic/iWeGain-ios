import Foundation

/// Teams I joined: I decide whether each team leader can see and change my data, or leave.
final class TeamsImInViewModel: BaseViewModel<TeamsImInState, TeamsImInAction, TeamsImInEvent> {
    private static let leaderColors: [AvatarColor] = [.blue, .orange, .purple, .pink]

    private let teamRepository: TeamRepository
    private var isObserving = false

    init(teamRepository: TeamRepository) {
        self.teamRepository = teamRepository
        super.init(initialState: TeamsImInState())
    }

    override func onAction(_ action: TeamsImInAction) {
        switch action {
        case .onAppear: observe()
        case .onAccessChange(let ownerUid, let access): setAccess(ownerUid: ownerUid, access: access)
        case .onLeaveTap(let team): updateState { $0.leaving = team }
        case .onLeaveDismiss: updateState { $0.leaving = nil }
        case .onLeaveConfirm: leave()
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        // Weak, so the Firestore listener stops when the screen goes away.
        let memberships = teamRepository.observeMemberships()
        launch { [weak self] in
            for await list in memberships {
                self?.updateState {
                    $0.teams = Self.teams(list)
                    $0.isLoading = false
                }
            }
        }
    }

    static func teams(_ memberships: [TeamMembership]) -> [MembershipUi] {
        memberships
            .sorted { ($0.joinedAt ?? .distantFuture) < ($1.joinedAt ?? .distantFuture) }
            .enumerated()
            .map { index, team in
                MembershipUi(
                    ownerUid: team.ownerUid,
                    ownerName: team.ownerName,
                    initials: User.initials(of: team.ownerName),
                    color: leaderColors[index % leaderColors.count],
                    caption: team.joinedAt.map { Strings.format("teams_im_in_leader_joined", $0.formatted(.dateTime.month(.abbreviated).day())) }
                        ?? Strings.text("teams_im_in_leader"),
                    hasAccess: team.hasAccess
                )
            }
    }

    private func setAccess(ownerUid: String, access: Bool) {
        // Shown right away; the Firestore listener confirms it (or reverts it after a failure).
        updateState { state in
            if let index = state.teams.firstIndex(where: { $0.ownerUid == ownerUid }) { state.teams[index].hasAccess = access }
        }
        launch { [self] in
            do throws(TeamError) {
                try await teamRepository.setAccess(ownerUid: ownerUid, access: access)
            } catch {
                sendEvent(.showMessage(error.message))
            }
        }
    }

    private func leave() {
        guard let team = state.leaving, !state.isLeaving else { return }
        launch { [self] in
            updateState { $0.isLeaving = true }
            do throws(TeamError) {
                try await teamRepository.leaveTeam(ownerUid: team.ownerUid)
            } catch {
                sendEvent(.showMessage(error.message))
            }
            updateState {
                $0.isLeaving = false
                $0.leaving = nil
            }
        }
    }
}

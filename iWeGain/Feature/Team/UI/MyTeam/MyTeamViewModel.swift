import Foundation

/// People in my team, then the profiles I created. Members can be removed (they decide whether I can see and
/// change their data); profiles can be edited, and deleting one deletes its data too.
final class MyTeamViewModel: BaseViewModel<MyTeamState, MyTeamAction, MyTeamEvent> {
    private let teamRepository: TeamRepository
    private let profileRepository: ProfileRepository
    private let userRepository: UserRepository
    private var isObserving = false

    init(teamRepository: TeamRepository, profileRepository: ProfileRepository, userRepository: UserRepository) {
        self.teamRepository = teamRepository
        self.profileRepository = profileRepository
        self.userRepository = userRepository
        super.init(initialState: MyTeamState())
    }

    override func onAction(_ action: MyTeamAction) {
        switch action {
        case .onAppear: observe()
        case .onInviteTap: sendEvent(.navigateToInvite)
        case .onCreateProfileTap: sendEvent(.navigateToCreateProfile)
        case .onMemberTap(let member):
            if member.isProfile { sendEvent(.navigateToEditProfile(profileId: member.uid)) }
        case .onRemoveTap(let member): updateState { $0.removing = member }
        case .onRemoveDismiss: updateState { $0.removing = nil }
        case .onRemoveConfirm: remove()
        }
    }

    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        // Weak, so the Firestore listeners stop when the screen goes away.
        let people = combineLatest(teamRepository.observeMyTeam(), profileRepository.observeProfiles(), userRepository.observeUsers())
        launch { [weak self] in
            for await (team, profiles, users) in people {
                self?.updateState {
                    $0.members = Self.members(team: team, profiles: profiles, users: users)
                    $0.isLoading = false
                }
            }
        }
    }

    /// Colors and photos come from the people list, so a person looks the same here and in the switcher.
    static func members(team: [TeamMember], profiles: [Profile], users: [User]) -> [MemberUi] {
        let people = Dictionary(users.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let members = team.sorted { ($0.joinedAt ?? .distantFuture) < ($1.joinedAt ?? .distantFuture) }.map { member in
            let person = people[member.uid]
            let name = person?.name ?? member.name
            let joined = member.joinedAt.map { Strings.format("my_team_joined", $0.formatted(.dateTime.month(.abbreviated).day())) }
                ?? Strings.text("my_team_just_joined")
            return MemberUi(
                uid: member.uid,
                name: name,
                initials: User.initials(of: name),
                color: person?.avatarColor ?? .pink,
                caption: member.hasAccess ? joined : Strings.format("my_team_no_access", joined),
                photo: person?.photo
            )
        }
        let ownProfiles = profiles.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }.map { profile in
            MemberUi(
                uid: profile.id,
                name: profile.name,
                initials: User.initials(of: profile.name),
                color: profile.avatarColor,
                caption: Strings.text("my_team_profile_caption"),
                isProfile: true,
                photo: profile.photo
            )
        }
        return members + ownProfiles
    }

    private func remove() {
        guard let member = state.removing, !state.isRemoving else { return }
        launch { [self] in
            updateState { $0.isRemoving = true }
            if member.isProfile {
                do throws(ProfileError) {
                    try await profileRepository.deleteProfile(id: member.uid)
                } catch {
                    sendEvent(.showMessage(error.message))
                }
            } else {
                do throws(TeamError) {
                    try await teamRepository.removeMember(member.uid)
                } catch {
                    sendEvent(.showMessage(error.message))
                }
            }
            updateState {
                $0.isRemoving = false
                $0.removing = nil
            }
        }
    }
}
